require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'byebug'
require_relative 'model.rb'

enable :sessions
include Model

msg = ""
msgtype = ""

before do
    if (session[:username] == nil) && (request.path_info != '/') && (request.path_info != '/login') && (request.path_info != '/register/new')
      msg = "You need to log in to see this"
      msgtype= "errormsg"
      redirect('/')
    end
end
   

# Display starting page and optional message to the user
#
get('/') do
    session[:username] = nil
    slim(:"index", locals:{msg:msg, msgtype:msgtype})
end

#Registers a new user and inserts its login to the database, If the login is succesful the username is put in the session.
#
# @see Model#user_exists
# @see Model#create_user
post("/register/new") do
    errors = []
    username = params[:reg_username]
    if user_exists(username)
        errors << "There is a user with that name already!"
    end
    password = params[:reg_password]
    password_confirm = params[:reg_password_confirm]
    if (password != password_confirm)
        errors << "The passwords don't match!"
    end
    if username.length < 3
        if username.length < 1
            errors << "Enter a username!"
        else
            errors << "That username is too short!"
        end
    end
    if password.length < 3
        if password.length < 1
            errors << "Enter a password!"
        else
            errors << "That password is too short!"
        end
    end
    if errors.length != 0 
        msgtype="errormsg"
        msg = "Registration unsuccesful! You got #{errors.length} error(s)! "
        errors.each { |str| msg += str + " " }
    else
        password_digest = BCrypt::Password.create(password)
        create_user(username, password_digest)
        msg = "Registration succesful!"
        msgtype = ""
    end
    redirect("/")
    msg = ""
    msgtype = ""
end

#Attempts to log the user in and updates the session[:username] to match the username of the account.
#Sets a timer for a failed login to prevent spam and hacker attacks.
#
# @param [string] username, The entered username
# @param [password] password, The entered password
#
# @see Model#user_exists
# @see Model#get_user_info
post("/login") do
    error = false
    msg=""
    msgtype="errormsg"
    username = params[:username]
    password = params[:password]
    prev_login = session[:prev_login]
    if username.length < 3
        error=true
        if username.length < 1
            msg = "Enter a username"
        else
            msg = "That username is too short!"
        end
    end
    if password.length < 3
        error=true
        if password.length < 1
            msg = "Enter a password"
        else
            msg = "That password is too short!"
        end
    end

    if user_exists(username) == false && error == false
        error=true
        msg = "That username doesnt exist"
    end
    if prev_login != nil && error == false
        error = Time.now.to_i - prev_login <= 10? true : false
        msg = "You are loging in too fast!"
    end
    if error == false
        result = get_user_info(username)
        pwdigest = result["pwdigest"]
        id = result["id"]
        if BCrypt::Password.new(pwdigest) == password
            session[:id] = id
            session[:username] = username
            redirect("/quizzy")
        else
            error=true
            msg = "Wrong username/password"
        end
    end

    if error == true 
        prev_login = Time.now.to_i
        session[:prev_login] = prev_login
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
# @see Model#get_user_id
# @see Model#get_matches
# @see Model#get_match_info
# @see Model#Fet_user_username
get("/matches/index") do
    username = session[:username]
    matches = []
    id = get_user_id(username)
    match_ids = get_matches(id)
    match_ids.each do |current|
        matchinfo = get_match_info(current[0])
        matchinfo.push(get_user_username(current[1]), get_user_username(current[2]))
        matches.push(matchinfo)
    end
    slim(:"/quizzy/matches/index", locals:{matches:matches, msg:msg, msgtype:msgtype})
end

#Display the "Create a match" form for the user
get("/matches/new") do
    slim(:"/quizzy/matches/new", locals:{msg:msg, msgtype:msgtype})
end

#Attempts to create a new match against the opponent that the user wrote in their input
#
# @param [string] opponent_username, The entered opponent_username
#
# @see Model#get_user_id
# @see Model#user_exists
# @see Model#active_matches_exists
# @see Model#create_match
get("/matches/new/new") do
    msg=""
    msgtype=""
    error = false
    username = session[:username]
    opponent_username = params[:opponent_username]
    user_id = get_user_id(username)
    if user_exists(opponent_username) == false
        msg = "That user doesn't exist! try again."
        msgtype = "errormsg"
        error = true
        redirect("/matches/index")
    end
    opponent_id = get_user_id(opponent_username)
    if username == opponent_username
        msg = "You can't create a match against yourself!"
        msgtype = "errormsg"
        error = true
    elsif active_matches_exists(user_id, opponent_id)
        msg = "You already have a match with this user."
        msgtype = "errormsg"
        error = true
    elsif error == false
        create_match(user_id, opponent_id)
        msgtype = ""
        msg = "Match created!"
    end
    redirect("/matches/new")
end

#Displays the "edit matches" page for the user
#
# @see Model#get_user_id
# @see Model#get_matches
# @see Model#get_match_info
# @see Model#get_user_username
get("/matches/edit") do
    username = session[:username]
    matches = []
    id = get_user_id(username)
    match_ids = get_matches(id)
    match_ids.each do |current|
        matchinfo = get_match_info(current[0])
        matchinfo.push(get_user_username(current[1]), get_user_username(current[2]))
        matches.push(matchinfo)
    end
    slim(:"/quizzy/matches/edit", locals:{matches:matches, msg:msg, msgtype:msgtype})
end

# Deletes a match
#
# @param [id] match_id, The chosen match;s id
#
# @see Model#delete_match
get("/matches/delete") do
    match_id=params[:match_id]
    delete_match(match_id)
    redirect("matches/edit")
end

#Shows the "pick category" phase of the match for the user
#
# @see Model#get_opponent_id
# @see Model#status_1_or_2
# @see Model#get_all_categories
# @see Model#get_questions
# @see Model#get_question_info
post("/matches/show/start") do
    match_id=params[:match_id]
    session[:match_id] = match_id
    username= session[:username]
    opponent_id = get_opponent_id(username, match_id)
    session[:opponent_id] = opponent_id
    if status_1_or_2(match_id)
        categories = get_all_categories()
        shuffled = categories.shuffle[0..2]
        status="start"
        slim(:"/quizzy/matches/show", locals:{categories:shuffled, status:status, match_id:match_id})
    else
        status="answer"
        question_ids=[]
        3.times do |i| 
            question_ids << get_question(match_id, i+1)
        end
        questions = get_question_info(question_ids)       
        slim(:"/quizzy/matches/show", locals:{questions:questions, status:status, match_id:match_id})
    end
end

# Picks the questions and redirects the user so they are able to anwser them.
#
# @param [integer] categories, The chosen category id
#
# @see Model#pick_questions
# @see Model#set_category_and_questions
post("/matches/show/category_chosen") do
    status = "answer"
    category = params[:categories]
    match_id=session[:match_id]
    questions = pick_questions(category)
    set_category_and_questions(category, questions, match_id)
    slim(:"/quizzy/matches/show", locals:{questions:questions, status:status, match_id:match_id})
end

#Corrects the anwsers from the user and adds the amount of correct anwsers to their score, also keeps track of how many turns has been played and whose turn it is. When the match is finished, ranking is decreased for the loser of the match and increased for the winner.
# 
# @param [array] questions, The anwsered questions
#
# @see Model#get_user_id'
# @see Model#correct_answer
# @see Model#get_primary_user
# @see Model#get_match_info
# @see Model#update_match_turn
# @see Model#update_match_score_status
# @see Model#update_match_finished
post("/matches/show/answered") do
    user_id = get_user_id(session[:username])
    match_id = session[:match_id]
    questions = params[:questions]
    questions = eval(questions)
    answers = params[questions[0]["question_id"].to_s.to_sym].to_i, params[questions[1]["question_id"].to_s.to_sym].to_i, params[questions[2]["question_id"].to_s.to_sym].to_i
    score = 0
    answers.each_with_index do |answer, index|
        score += correct_answer(answer, questions, index)
    end
    userscore = get_primary_user(user_id, match_id)
    if userscore == "user_1_score"
        status = get_match_info(match_id)[0]["status"] == 1? 4:1
    else
        status = get_match_info(match_id)[0]["status"] == 2? 3:2
    end
    update_match_turn(match_id)
    scoreupdate = get_match_info(match_id)[0][userscore].to_i + score
    update_match_score_status(userscore, scoreupdate, status, match_id)
    if get_match_info(match_id)[0]["turn"] >= 2
         user1score= get_match_info(match_id)[0]["user_1_score"].to_i
         user2score= get_match_info(match_id)[0]["user_2_score"].to_i
         if user1score != user2score
            if userscore == "user_1_score"
                winner = user1score > user2score ? user_id : session[:opponent_id]
                loser = user1score < user2score ? user_id : session[:opponent_id]
            else
                winner = user1score > user2score ? session[:opponent_id] : user_id
                loser = user1score < user2score ? session[:opponent_id] : user_id
            end
            scorediff = (user1score-user2score).abs
            update_match_finished(match_id, winner, scorediff, loser)
         end
     end
    redirect("/matches/index")
end

#Displays the leaderboard of the top 10 users
#
# @see Model#get_top_users
get("/leaderboard") do
    users = get_top_users()
    slim(:"/quizzy/leaderboard", locals:{users:users})
end

#Shows the profile page to the user.
#
# @see Model#get_user_id
# @see Model#get_user_info
# @see Model#get_user_matches
# @see Model#get_match_info
get("/profile/show") do
    userid = get_user_id(session[:username])
    rank = get_user_info(session[:username])["ranking"]
    matches_played = get_user_matches(userid)
    total = 0
    matches_played.each do |match|
        user = userid == match["user_1_id"] ? "user_1_score":"user_2_score"
        total += get_match_info(match["match_id"])[0]["#{user}"]
    end
    slim(:"/quizzy/profile/show", locals:{rank:rank, matches_played:matches_played.count, correct:total})
end

#Displays the adminpanel to the user, is only accessible to the admin
#
# @see Model#get_all_categories
get("/adminpanel") do
    if session[:username] != "admin"
        redirect("/")
    end
    categories = get_all_categories()
    slim(:"/quizzy/adminpanel", locals:{categories:categories})
end

#Creates a new question and inserts it to the questions database
#
# @param [integer] category, The chosen category id
# @param [string} questiontext, the entered question text
# @param [string] alternative_1, the entered alternative 1
# @param [string] alternative_2, the entered alternative 2
# @param [string] alternative_3, the entered alternative 3
# @param [string] alternative_4, the entered alternative 4
# @param [integer] right_alternative, the correct_alternative
#
# @see Model#create_new_question
get("/adminpanel/new_question") do
    category_id = params[:category].to_i
    question = params[:questiontext]
    alternative_1 = params[:alternative_1]
    alternative_2 = params[:alternative_2]
    alternative_3 = params[:alternative_3]
    alternative_4 = params[:alternative_4]
    right_alternative = params[:right_alternative]
    create_new_question(category_id, alternative_1, alternative_2, alternative_3, alternative_4, right_alternative, question)
    redirect("/adminpanel")
end

#Deletes a question, removes it from the database
#
# @param [integer] questionid, The entered questionid
#
# @see Model#delete_question
get("/adminpanel/delete_question") do
    questionid = params[:questionid]
    delete_question(questionid)
    redirect("/adminpanel")
end