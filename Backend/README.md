# Podcast History Backend

REST API for the Flutter application, built with Java 17, Maven, Spring Boot 4.1.1, Spring Data JPA, and PostgreSQL 18.

## Create the database

The connection defaults to the exact-case database name `Podcast_History` on `localhost:5432`. Create it once from this directory with the setup script. It asks for the PostgreSQL role and password locally; the password is not written to the project:

```powershell
.\create_database.ps1
```

## Run locally

Set the PostgreSQL credentials in the current PowerShell session, then run from this `Backend` directory:

```powershell
$env:DB_USERNAME = 'postgres'
$env:DB_PASSWORD = '<your PostgreSQL password>'
mvn spring-boot:run
```

On startup, Hibernate creates or updates the 39 tables from the entities, and the application seeds the three system roles and the `PLATFORM_MAIN` system wallet. It does not drop existing tables or data.

The server listens on `http://localhost:8081`. Check that it is running at:

```text
GET http://localhost:8081/api/health
```

It returns:

```json
{"status":"UP","service":"podcast-history-backend"}
```

For Flutter on an Android emulator, use `http://10.0.2.2:8081` as the API base URL. For Flutter on a physical device, use the computer's LAN IP address and ensure both devices are on the same network.
