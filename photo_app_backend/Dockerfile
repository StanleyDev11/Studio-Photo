# Étape 1: Build de l'application avec Maven
# Utilise une image qui contient Maven et le JDK 17
FROM maven:3.8.5-openjdk-17 AS build

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
# Utilise une image légère avec seulement l'environnement d'exécution Java 17
FROM eclipse-temurin:17-jre-jammy

# Définit le répertoire de travail
WORKDIR /app

# Copie le fichier .jar qui a été généré à l'étape précédente
# Le chemin exact du .jar dépend de la configuration dans votre pom.xml (artifactId et version)
# Je vais utiliser un wildcard (*) pour le rendre plus flexible.
COPY --from=build /app/target/*.jar app.jar

# Expose le port sur lequel l'application Spring Boot tourne (par défaut 8080)
EXPOSE 8080

# Commande pour démarrer l'application lorsque le conteneur est lancé
ENTRYPOINT ["java", "-jar", "app.jar"]
