# Nacos for Railway: official image, pinned by version and digest.
FROM nacos/nacos-server:v3.3.0@sha256:bf18e41d09efd4e72edc46b010d42dca49f776421413cb2637be1fff0d6ef90f

COPY railway/ /home/nacos/railway/

# Build the tiny first-boot helper (schema + admin seed) with the JDK already in the image.
RUN cd /home/nacos/railway \
 && python3 -c "import zipfile; z=zipfile.ZipFile('/home/nacos/target/nacos-server.jar'); [open(n.rsplit('/',1)[1],'wb').write(z.read(n)) for n in z.namelist() if n.startswith('BOOT-INF/lib/spring-security-crypto-') or n.startswith('BOOT-INF/lib/commons-logging-')]" \
 && java -m jdk.compiler/com.sun.tools.javac.Main -nowarn -cp "/home/nacos/plugins/mysql-connector-j-8.2.0.jar:$(ls spring-security-crypto-*.jar)" -d . RailwayInit.java \
 && rm RailwayInit.java \
 && chmod 755 start.sh

ENTRYPOINT ["bash", "/home/nacos/railway/start.sh"]
