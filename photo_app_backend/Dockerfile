# Étape 1: Build de l'application avec Maven
# Utilise une image OpenJDK 21 standard
FROM openjdk:21-jdk AS build

# Installe Maven
# openjdk:21-jdk est basée sur Debian, donc utilise apt
RUN apt-get update && apt-get install -y maven && rm -rf /var/lib/apt/lists/*

# Définit le répertoire de travail à l'intérieur du conteneur
WORKDIR /app

# Copie le fichier de configuration du projet Maven
COPY pom.xml .

# Copie le wrapper Maven (bonnes pratiques)
COPY .mvn .mvn

# Copie le reste du code source de l'application
COPY src src

# Lance la commande Maven pour packager l'application en un fichier .jar
# -DskipTests pour ne pas lancer les tests unitaires pendant le build de l'image
RUN mvn clean package -DskipTests

# Étape 2: Création de l'image finale
# Utilise une image plus générale avec JDK 21
FROM openjdk:21-jdk

# Définit le répertoire de travail
WORKDIR /app

# Copie le fichier .jar qui a été généré à l'étape précédente
COPY --from=build /app/target/*.jar app.jar

# Expose le port sur lequel l'application Spring Boot tourne (par défaut 8080)
EXPOSE 8080

# Commande pour démarrer l'application lorsque le conteneur est lancé
ENTRYPOINT ["java", "-jar", "app.jar"]
