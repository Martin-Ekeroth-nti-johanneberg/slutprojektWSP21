require 'sinatra'
require 'slim'
require 'byebug'
require 'sqlite3'
require 'bcrypt'

enable :sessions


module Model
    #Lets the user input a id and finds the username of that user
    #
    #@params [string]; The username that the user wants the id from.
    def get_user_id(username)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = false
        id = db.execute("SELECT user_id FROM users WHERE username = ?", username)[0][0]
        return id
    end
    
    #Lets the user input a user_id and finds the username of that user
    #
    #@params [integer]; The id that the user wants the username from.
    def get_user_username(id)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = false
        username = db.execute("SELECT username FROM users WHERE user_id = ?", id)[0][0]
        return username
    end

    def create_user(username, password_digest)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = false
        db.execute("INSERT INTO users (username, pwdigest, ranking) VALUES (?, ?, ?)",username,password_digest, 1000)
    end

    def user_exists(username)
        db = SQLite3::Database.new('db/quizzy.db')
        return db.execute("SELECT user_id FROM users WHERE username=?", username)[0]!=nil
    end

    def get_user_info(username)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = true
        result = db.execute("SELECT * FROM users WHERE username = ?", username).first
        return result
    end

    def get_matches(user_id)
        db = SQLite3::Database.new('db/quizzy.db')
        result = db.execute("SELECT * FROM users_matches_relations WHERE user_1_id = ? OR user_2_id = ?", user_id, user_id)
        return result
    end

    def get_match_info(match_id)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = true
        result = db.execute("SELECT * FROM matches WHERE match_id = ?", match_id)
        return result
    end

    def active_matches_exists(user_id, opponent_id)
        db = SQLite3::Database.new('db/quizzy.db')
        db.execute("SELECT match_id FROM users_matches_relations WHERE user_1_id = ? AND user_2_id = ? AND finished = 0 OR user_1_id = ? AND user_2_id = ? AND finished = 0", user_id, opponent_id, opponent_id, user_id)[0]!=nil 
    end

    def create_match(user_id, opponent_id)
        db = SQLite3::Database.new('db/quizzy.db')
        db.execute("INSERT INTO users_matches_relations (user_1_id, user_2_id, finished) VALUES(?, ?, 0)",user_id, opponent_id)
        match_id = db.execute("SELECT match_id FROM users_matches_relations WHERE user_1_id = ? AND user_2_id = ? AND finished = 0", user_id, opponent_id)[0]
        db.execute("INSERT INTO matches (match_id, status, user_1_score, user_2_score, turn) VALUES (?, 1, 0, 0, 0)", match_id)
    end
    
    def get_opponent_id(username, match_id)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = true
        result = get_user_id(username) == db.execute("SELECT user_1_id FROM users_matches_relations WHERE match_id = #{match_id}")[0]["user_1_id"]? db.execute("SELECT user_2_id FROM users_matches_relations WHERE match_id = #{match_id}")[0]["user_2_id"] : db.execute("SELECT user_1_id FROM users_matches_relations WHERE match_id = #{match_id}")[0]["user_1_id"]
        return result
    end

    def status_1_or_2(match_id)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = true
        p db.execute("SELECT status FROM matches WHERE match_id= ?", match_id)[0]["status"]
        return [1,2].include? db.execute("SELECT status FROM matches WHERE match_id= ?", match_id)[0]["status"] 
    end

    def pick_questions(category)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = true
        return db.execute("SELECT * FROM questions WHERE belongs_to_category = #{category}").shuffle[0..2]
    end

    def get_question(match_id, i)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = true
        return db.execute("SELECT question_#{i}_id FROM matches WHERE match_id = ?", match_id)[0]["question_#{i}_id"]
    end

    def get_question_info(question_ids)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = true
        return db.execute("SELECT * FROM questions WHERE question_id = ? OR question_id = ? OR question_id = ?", question_ids[0],question_ids[1],question_ids[2])
    end

    def set_category_and_questions(category, questions, match_id)
        db = SQLite3::Database.new('db/quizzy.db')
        db.execute("UPDATE matches SET category_id = #{category}, question_1_id= ?, question_2_id= ?, question_3_id= ? WHERE match_id = ?", questions[0]["question_id"], questions[1]["question_id"], questions[2]["question_id"], match_id)
    end

    def correct_answer(answer, questions, i)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = true
        return answer == db.execute("SELECT right_alternative FROM questions WHERE question_id = ?", questions[i]["question_id"])[0]["right_alternative"]? 1:0 
    end

    def get_primary_user(user_id, match_id)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = true
        return user_id == db.execute("SELECT user_1_id FROM users_matches_relations WHERE match_id = ?", match_id)[0]["user_1_id"]? "user_1_score":"user_2_score" 
    end

    def update_match_turn(match_id)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = true
        db.execute("UPDATE matches SET turn = ? WHERE match_id = ?", db.execute("SELECT turn FROM matches WHERE match_id= ?", match_id)[0]["turn"]+1, match_id)
    end

    def update_match_score_status(userscore, scoreupdate, status, match_id)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = true
        db.execute("UPDATE matches SET #{userscore} = ?, status = ? WHERE match_id = ?",scoreupdate, status, match_id)
    end

    def update_match_finished(match_id, winner, scorediff, loser)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = true
        db.execute("UPDATE matches SET status = ? WHERE match_id = ?", 5, match_id)
        db.execute("UPDATE users_matches_relations SET finished = 1 WHERE match_id = ?", match_id)
        db.execute("UPDATE users SET ranking = ? WHERE user_id = ?", db.execute("SELECT ranking FROM users WHERE user_id = ?", winner)[0]["ranking"]+scorediff, winner)
        db.execute("UPDATE users SET ranking = ? WHERE user_id = ?", db.execute("SELECT ranking FROM users WHERE user_id = ?", loser)[0]["ranking"]-scorediff, loser)
    end

    def get_top_users
        db = SQLite3::Database.new('db/quizzy.db')
        return db.execute("SELECT username, ranking FROM users").sort_by{|i|i[1]}.reverse.first(10)
    end

    def get_user_matches(userid)
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = true
       return db.execute("SELECT * FROM users_matches_relations WHERE user_1_id = #{userid} OR user_2_id = #{userid}")
    end

    def get_all_categories
        db = SQLite3::Database.new('db/quizzy.db')
        db.results_as_hash = true
        return db.execute("SELECT * FROM categories")
    end
    
    def create_new_question(category_id, alternative_1, alternative_2, alternative_3, alternative_4, right_alternative, question)
        db = SQLite3::Database.new('db/quizzy.db')
        db.execute("INSERT INTO questions (belongs_to_category, alternative_1, alternative_2, alternative_3, alternative_4, right_alternative, question_text) VALUES (?, ?, ?, ?, ?, ?, ?)", category_id, alternative_1, alternative_2, alternative_3, alternative_4, right_alternative, question)
    end
    
    def delete_question(question_id)
        db = SQLite3::Database.new('db/quizzy.db')
        db.execute("DELETE FROM questions WHERE question_id = ?", question_id)
    end

    def delete_match(match_id)
        db = SQLite3::Database.new('db/quizzy.db')
        db.execute("DELETE FROM matches WHERE match_id = ?", match_id)
        db.execute("DELETE FROM users_matches_relations WHERE match_id = ?", match_id)
    end
end