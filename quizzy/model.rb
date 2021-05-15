require 'sinatra'
require 'slim'
require 'byebug'
require 'sqlite3'
require 'bcrypt'

enable :sessions

module Model
    def get_db
        db = SQLite3::Database.new('db/quizzy.db')
        return db
    end

    #Lets the user input a id and finds the username of that user
    #
    #@params [string]; The username that the user wants the id from.
    def get_user_id(username)
        db = SQLite3::Database.new('db/quizzy.db')
        id = db.execute("SELECT user_id FROM users WHERE username = ?", username)[0][0]
        return id
    end
    
    #Lets the user input a user_id and finds the username of that user
    #
    #@params [integer]; The id that the user wants the username from.
    def get_user_username(id)
        db = SQLite3::Database.new('db/quizzy.db')
        username = db.execute("SELECT username FROM users WHERE user_id = ?", id)[0][0]
        return username
    end

    def create_user(username, password_digest)
        db = SQLite3::Database.new('db/quizzy.db')
        db.execute("INSERT INTO users (username, pwdigest, ranking) VALUES (?, ?, ?)",username,password_digest, 1000)
    end
    end

