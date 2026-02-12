###############################
# Stage 1 — Build with Ant
###############################
FROM frekele/ant:1.10-jdk8 AS builder

# Set the working directory where build.xml is located
WORKDIR /app

# Copy the entire project (so relative paths work correctly)
COPY . /app

# Run Ant build (deploy target builds & copies exploded war)
RUN ant -f build.xml deploy


###############################
# Stage 2 — WildFly with built WAR
###############################
FROM jboss/wildfly:10.1.0.Final

# WildFly deployments directory
ENV DEPLOY_DIR=/opt/jboss/wildfly/standalone/deployments

# Copy the exploded WAR from builder stage into WildFly deploy folder
COPY --from=builder /opt/wildfly/standalone/deployments/kolotv.war ${DEPLOY_DIR}/kolotv.war

# Create marker so WildFly deploys at startup
RUN touch ${DEPLOY_DIR}/kolotv.war.dodeploy

ENV JAVA_OPTS="$JAVA_OPTS -Duser.language=fr -Duser.country=FR -Duser.timezone=Europe/Paris -Duser.region=FR"
EXPOSE 8080 9990

CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0"]
