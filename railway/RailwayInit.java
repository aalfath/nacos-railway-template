import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import org.springframework.security.crypto.bcrypt.BCrypt;

/** First-boot helper: applies the bundled MySQL schema (idempotent) and seeds the admin user once. */
public class RailwayInit {
    static String env(String k, String d) { String v = System.getenv(k); return v == null || v.isEmpty() ? d : v; }

    public static void main(String[] args) throws Exception {
        String url = "jdbc:mysql://" + env("MYSQL_SERVICE_HOST", "") + ":" + env("MYSQL_SERVICE_PORT", "3306") + "/"
                + env("MYSQL_SERVICE_DB_NAME", "") + "?" + env("MYSQL_SERVICE_DB_PARAM", "");
        Connection c = null;
        long deadline = System.currentTimeMillis() + 180_000;
        while (c == null) {
            try {
                c = DriverManager.getConnection(url, env("MYSQL_SERVICE_USER", ""), env("MYSQL_SERVICE_PASSWORD", ""));
            } catch (Exception e) {
                if (System.currentTimeMillis() > deadline) { System.err.println("[railway] MySQL not reachable: " + e.getMessage()); System.exit(1); }
                System.out.println("[railway] waiting for MySQL: " + e.getMessage());
                Thread.sleep(3000);
            }
        }
        try (Statement st = c.createStatement()) {
            try (ResultSet rs = st.executeQuery("SELECT GET_LOCK('nacos_railway_init', 300)")) {
                if (!rs.next() || rs.getInt(1) != 1) { System.err.println("[railway] could not get init lock"); System.exit(1); }
            }
            String sql = new String(Files.readAllBytes(Paths.get(args[0])), StandardCharsets.UTF_8);
            sql = sql.replaceAll("(?s)/\\*.*?\\*/", "").replaceAll("(?m)^\\s*--.*$", "");
            int n = 0;
            for (String s : sql.split(";")) {
                String t = s.trim();
                if (t.isEmpty()) continue;
                t = t.replaceFirst("(?i)^CREATE\\s+TABLE\\s+(?!IF\\s+NOT\\s+EXISTS)", "CREATE TABLE IF NOT EXISTS ");
                if (!t.regionMatches(true, 0, "CREATE TABLE", 0, 12)) { System.out.println("[railway] skipping non-DDL statement"); continue; }
                st.execute(t);
                n++;
            }
            System.out.println("[railway] schema ok (" + n + " tables checked)");

            int admins;
            try (ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM roles WHERE role='ROLE_ADMIN'")) { rs.next(); admins = rs.getInt(1); }
            if (admins == 0) {
                String hash = BCrypt.hashpw(env("NACOS_ADMIN_PASSWORD", ""), BCrypt.gensalt(10));
                try (PreparedStatement p = c.prepareStatement(
                        "INSERT INTO users (username, password, enabled) VALUES ('nacos', ?, TRUE) ON DUPLICATE KEY UPDATE password=VALUES(password), enabled=TRUE")) {
                    p.setString(1, hash); p.executeUpdate();
                }
                st.executeUpdate("INSERT IGNORE INTO roles (username, role) VALUES ('nacos', 'ROLE_ADMIN')");
                System.out.println("[railway] admin user 'nacos' created from NACOS_ADMIN_PASSWORD");
            } else {
                System.out.println("[railway] admin already exists, leaving it unchanged");
            }
            st.execute("SELECT RELEASE_LOCK('nacos_railway_init')");
        }
        c.close();
    }
}
