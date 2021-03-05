require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'

enable :sessions

db = SQLite3::Database.new('db/quizzy.db')
msg = ""
msgtype = ""

def get_user_id(username)
    db = SQLite3::Database.new('db/quizzy.db')
    id = db.execute("SELECT user_id FROM users WHERE username = ?", username)[0][0]
    return id
end

def get_user_username(id)
    db = SQLite3::Database.new('db/quizzy.db')
    username = db.execute("SELECT username FROM users WHERE user_id = ?", id)[0][0]
    return username
end

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
    error = false
    msg=""
    msgtype=""
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
    slim(:"/quizzy/quizzy")
end

get("/matches") do
    username = session[:username]
    matches = []
    db.results_as_hash = false
    id = db.execute("SELECT user_id FROM users WHERE username = ?", username)[0][0]
    match_ids = db.execute("SELECT * FROM users_matches_relations WHERE user_1_id = ? OR user_2_id = ?", id, id)
    db.results_as_hash = true
    match_ids.each do |current|
        matchinfo = db.execute("SELECT * FROM matches WHERE match_id = ?", current[0])
        matchinfo.push(get_user_username(current[1]), get_user_username(current[2]))
        matches.push(matchinfo)
        p "matches = #{matches}"
    end
    slim(:"/quizzy/matches", locals:{matches:matches, msg:msg, msgtype:msgtype})
end

get("/matches/new") do
    msg=""
    msgtype=""
    db.results_as_hash = false
    error = false
    username = session[:username]
    opponent_username = params[:opponent_username]
    user_id = db.execute("SELECT user_id FROM users WHERE username = ?", username)[0][0]
    opponent_id = db.execute("SELECT user_id FROM users WHERE username = ?", opponent_username)[0][0]
    p "oop = #{db.execute("SELECT match_id FROM users_matches_relations WHERE user_1_id = ? AND user_2_id = ? OR user_1_id = ? AND user_2_id = ?", user_id, opponent_id, opponent_id, user_id)}"
    if db.execute("SELECT user_id FROM users WHERE username=?", opponent_username)[0]==nil
        msg = "That user doesn't exist! try again."
        msgtype = "errormsg"
        error = true
    elsif username == opponent_username
        msg = "You can't create a match against yourself!"
        msgtype = "errormsg"
        error = true
    elsif db.execute("SELECT match_id FROM users_matches_relations WHERE user_1_id = ? AND user_2_id = ? OR user_1_id = ? AND user_2_id = ?", user_id, opponent_id, opponent_id, user_id)[0]!=nil
        msg = "You already have a match with this user."
        msgtype = "errormsg"
        error = true
    elsif error == false
        db.execute("INSERT INTO users_matches_relations (user_1_id, user_2_id) VALUES(?, ?)",user_id, opponent_id)
        match_id = db.execute("SELECT match_id FROM users_matches_relations WHERE user_1_id = ? AND user_2_id = ?", user_id, opponent_id)
        db.execute("INSERT INTO matches (match_id, status, user_1_score, user_2_score) VALUES(?, 1, 0, 0)",match_id)
        msgtype = ""
        msg = "Match created!"
    end
    redirect("/matches")
end

post("/in_game/start") do
    categories=[0, 1, 2, 3, 4, 5]
    categories.shuffle[0..2]
    slim(:"/quizzy/in_game")
end