require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'

enable :sessions

db = SQLite3::Database.new('db/quizzy.db')
msg = ""
msgtype = ""

get('/') do
    slim(:"start", locals:{msg:msg, msgtype:msgtype})
end

post("/register/new") do
    errors = []
    username = params[:reg_username]
    if db.execute("SELECT user_id FROM users WHERE username=?", username)[0]!=nil
        errors << "There is a user with that name already!"
    end
    password = params[:reg_password]
    password_confirm = params[:reg_password_confirm]
    if (password != password_confirm)
        errors << "The passwords don't match!"
    end
    if errors.length != 0 
        msgtype="errormsg"
        msg = "Registration unsuccesful! You got #{errors.length} error(s)! "
        errors.each { |str| msg += str + " " }
    else
        password_digest = BCrypt::Password.create(password)
        db.execute("INSERT INTO users (username, pwdigest, role, ranking) VALUES (?, ?, ?, ?)",username,password_digest, "user", 1000)
        msg = "Registration succesful!"
        msgtype = ""
    end
    redirect("/")
    msg = ""
    msgtype = ""
end

post("/login") do
    username = params[:username]
    password = params[:password]
    if db.execute("SELECT user_id FROM users WHERE username=?", username)[0]==nil
        error=true
    else
        db.results_as_hash = true
        result = db.execute("SELECT * FROM users WHERE username = ?", username).first
        pwdigest = result["pwdigest"]
        id = result["id"]
        if BCrypt::Password.new(pwdigest) == password
            session[:id] = id
            session[:username] = username
            redirect("/quizzy")
        else
            error=true
        end
    end
    if error == true 
        msg = "Wrong username/password"
        msgtype="errormsg"
        redirect("/")
    end
end

get("/quizzy") do
    slim(:"/quizzy")
end

get("/matches") do
    username = session[:username]
    db.results_as_hash = false
    matches = db.execute("SELECT matches FROM users WHERE username=?", username)
    slim(:"/matches", locals:{matches:matches})
end