require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'

enable :sessions

errormsg = ""

get('/') do
    slim(:"start", locals:{errormsg:errormsg})
end

post("/register/new") do
    username = params[:reg_username]
    password = params[:reg_password]
    password_confirm = params[:reg_password_confirm]
    if (password == password_confirm)
        password_digest = BCrypt::Password.create(password)
        db = SQLite3::Database.new('db/quizzy.db')
        db.execute("INSERT INTO users (username, pwdigest, role, ranking) VALUES (?, ?, ?, ?)",username,password_digest, "user", 1000)
    else
        errormsg = "Passwords don't match!"
    end
    redirect("/")
    errormsg=""
end