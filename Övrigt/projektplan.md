# Projektplan

## 1. Projektbeskrivning (Beskriv vad sidan ska kunna göra).
Ett quiz-spel där man ska kunna registrera sig och logga in för att sedan kunna tävla mot sina kompisar. Spelet ska gå ut på att man får en fråga med fyra svarsalternativ och att man sedan får svara på dem. När man vinner/förlorar matcher så får man högre/lägre rankning och på sidan ska det finnas ett leaderboard som listar spelarna med högst ranking.

Extra idéer att lägga till om jag hinner:
-Profilbild?
-Level system där man levlar av att vinna matcher
-Olika "fusk" som man kan "köpa"
-Achievments?
-Skicka in förslag till frågor.
## 2. Vyer (visa bildskisser på dina sidor).
## 3. Databas med ER-diagram (Bild på ER-diagram).
Se new_erdiagram.png
## 4. Arkitektur (Beskriv filer och mappar - vad gör/innehåller de?).
Views:
    Kodfiler som bygger front end sidorna som användaren interegerar med.
db:
    quizzy.db: Databasen där allting lagras, innehåller categories, matches, questions, users, users_matches_relations
quizzy.rb:
    Ruby filen som sköter all back-end jobb.

