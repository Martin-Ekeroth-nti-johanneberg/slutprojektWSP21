require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'

enable :sessions

db = SQLite3::Database.new('db/quizzy.db')
msg = ""
msgtype = ""


#Lets the user input a username and finds the id of that user
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

# Displays the starting page and, if supplied, a message from the terminal to the user
#
get('/') do
    slim(:"start", locals:{msg:msg, msgtype:msgtype})
end

#Registers a new user and inserts its login to the database, If the login is succesful the username is put in the session.
#
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

#Attempts to log the user in and updates the session
#
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

# Shows the main page with a new nav.
#
get("/quizzy") do
    slim(:"/quizzy/quizzy")
end

#Shows the "Matches" page for the user
#
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

#Attempts to create a new match against the opponent that the user wrote in their input
#
get("/matches/new") do
    msg=""
    msgtype=""
    db.results_as_hash = false
    error = false
    username = session[:username]
    opponent_username = params[:opponent_username]
    user_id = get_user_id(username)
    opponent_id = get_user_id(opponent_username)
    session[:opponent_id] = opponent_id
    if db.execute("SELECT user_id FROM users WHERE username=?", opponent_username)[0]==nil
        msg = "That user doesn't exist! try again."
        msgtype = "errormsg"
        error = true
    elsif username == opponent_username
        msg = "You can't create a match against yourself!"
        msgtype = "errormsg"
        error = true
    elsif db.execute("SELECT match_id FROM users_matches_relations WHERE user_1_id = ? AND user_2_id = ? AND finished = 0 OR user_1_id = ? AND user_2_id = ? AND finished = 0", user_id, opponent_id, opponent_id, user_id)[0]!=nil
        msg = "You already have a match with this user."
        msgtype = "errormsg"
        error = true
    elsif error == false
        db.execute("INSERT INTO users_matches_relations (user_1_id, user_2_id, finished) VALUES(?, ?, 0)",user_id, opponent_id)
        match_id = db.execute("SELECT match_id FROM users_matches_relations WHERE user_1_id = ? AND user_2_id = ? AND finished = 0", user_id, opponent_id)[0]
        p match_id
        db.execute("INSERT INTO matches (match_id, status, user_1_score, user_2_score, turn) VALUES (?, 1, 0, 0, 0)", match_id)
        msgtype = ""
        msg = "Match created!"
    end
    redirect("/matches")
end


#Shows the "pick category" phase of the match for the user
#
post("/in_game/start") do
    match_id=params[:match_id]
    session[:match_id] = match_id
    db.results_as_hash =  true
    if [1,2].include? db.execute("SELECT status FROM matches WHERE match_id= ?", match_id)[0]["status"]
        categories = db.execute("SELECT * FROM categories")
        shuffled = categories.shuffle[0..2]
        status="start"
        slim(:"/quizzy/in_game", locals:{categories:shuffled, status:status, match_id:match_id})
    else
        status="answer"
        question_ids=[]
        3.times do |i| 
            question_ids << db.execute("SELECT question_#{i+1}_id FROM matches WHERE match_id = ?", match_id)[0]["question_#{i+1}_id"]
        end
        questions = db.execute("SELECT * FROM questions WHERE question_id = ? OR question_id = ? OR question_id = ?", question_ids[0],question_ids[1],question_ids[2])        
        slim(:"/quizzy/in_game", locals:{questions:questions, status:status, match_id:match_id})
    end
end

# Picks the questions and redirects the user so they are able to anwser them.
#
post("/in_game/category_chosen") do
    status = "answer"
    category = params[:categories]
    match_id=session[:match_id]
    db.results_as_hash = true
    questions = db.execute("SELECT * FROM questions WHERE belongs_to_category = #{category}").shuffle[0..2]
    db.execute("UPDATE matches SET category_id = #{category}, question_1_id= ?, question_2_id= ?, question_3_id= ? WHERE match_id = ?", questions[0]["question_id"], questions[1]["question_id"], questions[2]["question_id"], match_id)
    slim(:"/quizzy/in_game", locals:{questions:questions, status:status, match_id:match_id})
end

#Corrects the anwsers from the user and adds the amount of correct anwsers to their score, also keeps track of how many turns has been played and whose turn it is. When the match is finished, ranking is decreased for the loser of the match and increased for the winner.
#
post("/in_game/answered") do
    user_id = get_user_id(session[:username])
    match_id = session[:match_id]
    questions = params[:questions]
    questions = eval(questions) 
    answers = params[questions[0]["question_id"].to_s.to_sym].to_i, params[questions[1]["question_id"].to_s.to_sym].to_i, params[questions[2]["question_id"].to_s.to_sym].to_i
    score = 0
    answers.each_with_index do |answer, index|
        score += answer == db.execute("SELECT right_alternative FROM questions WHERE question_id = ?", questions[index]["question_id"])[0]["right_alternative"]? 1:0
    end
    userscore = user_id == db.execute("SELECT user_1_id FROM users_matches_relations WHERE match_id = ?", match_id)[0]["user_1_id"]? "user_1_score":"user_2_score"
    if userscore == "user_1_score"
        status = db.execute("SELECT status FROM matches WHERE match_id= ?", match_id)[0]["status"] == 1? 4:1
    else
        status = db.execute("SELECT status FROM matches WHERE match_id= ?", match_id)[0]["status"] == 2? 3:2
    end
    db.execute("UPDATE matches SET turn = ? WHERE match_id = ?", db.execute("SELECT turn FROM matches WHERE match_id= ?", match_id)[0]["turn"]+1, match_id)
    scoreupdate = db.execute("SELECT #{userscore} FROM matches WHERE match_id = ?", match_id)[0][userscore].to_i + score
    db.execute("UPDATE matches SET #{userscore} = ?, status = ? WHERE match_id = ?",scoreupdate, status, match_id)
    if db.execute("SELECT turn FROM matches WHERE match_id= ?", match_id)[0]["turn"] == 10
         db.execute("UPDATE matches SET status = ? WHERE match_id = ?", 5, match_id)
         db.execute("UPDATE users_matches_relations SET finished = 1 WHERE match_id = ?", match_id)
         user1score= db.execute("SELECT user_1_score, user_2_score FROM matches WHERE match_id = ?", match_id)[0]["user_1_score"].to_i
         user2score= db.execute("SELECT user_1_score, user_2_score FROM matches WHERE match_id = ?", match_id)[0]["user_2_score"].to_i
         if user1score != user2score
            winner = user1score < user2score ? user_id : session[:opponent_id]
            loser = user1score > user2score ? user_id : session[:opponent_id]
            db.execute("UPDATE users SET ranking = ? WHERE user_id = ?", db.execute("SELECT ranking FROM users WHERE user_id = ?", winner)[0]["ranking"]+10, winner)
            db.execute("UPDATE users SET ranking = ? WHERE user_id = ?", db.execute("SELECT ranking FROM users WHERE user_id = ?", loser)[0]["ranking"]-10, loser)
         end
     end
    redirect("/matches")
end

get("/leaderboard") do
    db.results_as_hash = true
    users = db.execute("SELECT username, ranking FROM users").sort_by{|username, ranking| ranking}
    p users
    slim(:"/quizzy/leaderboard")
end