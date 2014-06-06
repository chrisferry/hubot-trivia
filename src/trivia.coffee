# Description
#   A multiplayer trivia game.
#
# Dependencies:
#   sqlite3
#
# Configuration:
#   None
#
# Commands:
#   !trivia, !trivia help, !hint, !reveal, !end
#
# Author:
#   Josh Vazquez
#   Chris Ferry
#
# Version:
#   0.3.0

class Game

  constructor: (msg, robot) ->
    @allQuestions = []
    @allAnswers = []
    @hintArray = []
    @maxquestions = 1
    @dbfile = "scripts/questions.db"
    @sqlite3 = require "sqlite3"
    @db = new @sqlite3.Database(@dbfile, @sqlite3.OPEN_READONLY)
    @db.all "SELECT rowid, category, title FROM questions ORDER BY RANDOM() LIMIT 1", (err, allQuestions) => # array of question dictionaries having rowid, category, title keys
      @allQuestions = allQuestions
      @i = 0
      @firstAnswerDone = 0
      for q in @allQuestions
        @db.all ("SELECT id, answer FROM answers WHERE id = " + q['rowid']), (err, answersForQuestion) => # array of answer dictionaries matching question id
          @allAnswers[@i] = answersForQuestion # adds answer array to master array
          @i++
          if @firstAnswerDone == 0 # waits until answers retrieved before running playQuestion(), only runs it once
            @playQuestion(@msg)
          @firstAnswerDone = 1

    @currentQuestion = 0 # 0-9
    @hintsGiven = 0
    @correctAnswer = ""
    @hintAnswer = ""
    @msg = msg
    @robot = robot

    @msg.send "Welcome to trivia. Say \"!trivia help\" to see available commands."

  playQuestion: (msg) ->
    @hintsGiven = 0
    @hintArray = []
    @hintAnswer = ""
    if @allQuestions[@currentQuestion]['category'] == ""
      msg.send "Question: " + @allQuestions[@currentQuestion]['title']
    else
      msg.send "Question: - [ " + @allQuestions[@currentQuestion]['category'] + " ] " + @allQuestions[@currentQuestion]['title']
    @correctAnswer = @allAnswers[@currentQuestion][0]['answer']
    console.log "Correct answer: " + @correctAnswer

  tryGuess: (guess) ->
    answered = 0
    for answer in @allAnswers[@currentQuestion]
      if guess.toLowerCase().indexOf(answer['answer'].toLowerCase()) >= 0 and answered == 0 # if guess contains answer
        answered = 1
        @g = 0
        gameExists = 0
        @msg.send answer['answer'] + " is correct!"
        @currentQuestion++ # to next question

        # SCORING
        if !@robot.brain.get(@msg.message.user.name)
          @robot.brain.set @msg.message.user.name, 0
          @robot.brain.set (@msg.message.user.name + "_q"), 0 # q = questions answered
          @robot.brain.set (@msg.message.user.name + "_g"), 0 # g = games won
          @robot.brain.set (@msg.message.user.name + "_p"), 0 # p = points

        @robot.brain.set (@msg.message.user.name + "_q"), (@robot.brain.get(@msg.message.user.name + "_q") + 1)
        @robot.brain.set (@msg.message.user.name + "_p"), (@robot.brain.get(@msg.message.user.name + "_p") + 1)
        @msg.send @msg.message.user.name + " has answered " + @robot.brain.get(@msg.message.user.name + "_q") + " questions and has " + @robot.brain.get(@msg.message.user.name + "_p") + " points."
        # END SCORING

        if @currentQuestion < 1
          @playQuestion(@msg)
          @hintAnswer = "" # reset hint between word so length doesn't stay the same
    if !answered
      @msg.send "Sorry " + @msg.message.user.name + ", that is incorrect"

  reveal: (msg) ->
    answers = []
    for answer in @allAnswers[@currentQuestion]
      answers.push(answer['answer'])
    @msg.send "Answer(s): " + answers.join()

  hint: (msg) ->
    if @hintsGiven == 0
      i = 0
      while i < @correctAnswer.length
        if @correctAnswer[i] == " " or @correctAnswer[i] == "-"
          @hintArray[i] = @correctAnswer[i]
        else
          @hintArray[i] = "_"
        i++
      @hintAnswer = @hintArray.join("")

      @hintsGiven++
      msg.send "Hint: " + @hintAnswer + " (" + @hintAnswer.length + " characters)"

    else if @hintAnswer.indexOf("_") == -1
      msg.send "Are you sure you need a hint?"
    else
      r = Math.floor(Math.random() * @hintAnswer.length)
      while @hintAnswer[r] != "_" # randomize again if the selected letter is not blank
        console.log "re-randomized"
        r = Math.floor(Math.random() * @hintAnswer.length)
      if @hintAnswer[r] == "_"
        @hintArray = []
        for c in @hintAnswer
          @hintArray.push c
        @hintArray[r] = @correctAnswer[r]
        @hintAnswer = @hintArray.join("")
      msg.send "Hint: " + @hintAnswer + "(" + @hintAnswer.length + " characters)"

gameExists = 0

module.exports = (robot) =>
  robot.hear /(.*)/i, (msg) ->
    if msg.match[1] is "!trivia help"
      showHelp(msg)

    else if msg.match[1] is "!trivia"
      if gameExists is 0 or !gameExists # game not running
        @g = new Game(msg, robot) # create game
        gameExists = 1
      else if gameExists is 1 # game running
        msg.send "Game is already running. Say \"!trivia help\" to see available commands."

    else if msg.match[1] is "!hint"
      if gameExists is 1
        @g.hint(msg)
    else if msg.match[1] is "!reveal"
      if gameExists is 1
        @g.reveal(msg)
        @g = 0
        gameExists = 0

    else if msg.match[1] is "!end"
      if gameExists is 1
        @g = 0
        gameExists = 0
        msg.send "Game ended."

    else # assume other messages are guesses while the game is running
      if gameExists is 1
        @g.tryGuess(msg.match[1])
        if @g.currentQuestion > 0
          @g = 0
          gameExists = 0

showHelp = (msg) ->
  msg.send "Available commands: !trivia, !trivia help, !trivia score, !hint, !reveal, !end"