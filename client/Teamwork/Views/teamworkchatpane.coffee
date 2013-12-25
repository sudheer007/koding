class TeamworkChatPane extends ChatPane

  constructor: (options = {}, data) ->

    super options, data

    @setClass "tw-chat"
    @getDelegate().setClass "tw-chat-open"

    @on "NewChatItemCreated", @bound "checkForSystemAction"

  createDock: ->
    @dock = new KDCustomHTMLView cssClass: "hidden"

  updateCount: (count) ->

  sendMessage: (messageData, isSystemMessage) ->
    cssClass = ""
    nickname = KD.nick()

    if isSystemMessage
      cssClass = "tw-bot-message"
      nickname = "teamwork"

    message    =
      user     : { nickname }
      time     : Date.now()
      body     : messageData.message
      by       : messageData.by
      cssClass : cssClass            or ""
      system   : isSystemMessage     or no

    @chatRef.child(message.time).set message

  createNewChatItem: (params) ->
    return if @shouldBeHidden_ params

    super

  appendToChatItem: (params) ->
    return if @shouldBeHidden_ params

    if params.ownerNickname is "teamwork"
      @createNewChatItem params
    else
      super

  shouldBeHidden_: (params) ->
    {details}       = params
    isSystemMessage = details.system
    originUser      = details.by

    return originUser is KD.nick() and isSystemMessage

  checkForSystemAction: ->
    splitted = @lastMessageBody.split " "
    [key]    = splitted

    messageToMethod =
      help          : "replyForSystemHelp"
      invite        : "replyForInvite"
      watch         : "replyForWatch"
      join          : "replyForJoin"

    splitted.shift() # remove first item and update the array instance
    @[messageToMethod[key]]? splitted

  replyForSystemHelp: ->
    message = """
        Type "invite username" to invite someone to your session.
        Type "watch username"  to watch changes of somebody.
        Type "join sessionKey" to join a session.
      """
    @botReply message

  replyForJoin: (sessionKey) ->
    return if sessionKey.length > 1
    # TODO: fatihacet - we need to use a regex to check it's a real sessionKey
    sessionKey = sessionKey.first

    if sessionKey.indexOf("_") > -1
      @botReply "Validating the session key, #{sessionKey}", yes
      @workspace.firebaseRef.child(sessionKey).once "value", (snapshot) =>
        if snapshot.val() is null or not snapshot.val().keys
          @botReply "This session is no longer active, you cannot join."
        else
          @botReply "Joining to session, #{sessionKey}"
          @workspace.getDelegate().emit "JoinSessionRequested", sessionKey
    else
      # TODO: fatihacet - implement getting the sessionKey via username

  replyForInvite: (usernames) ->
    # TODO: fatihacet - currently invite only first user
    username = usernames.first
    return if usernames.length is 0 or username.trim() is ""

    # TODO: fatihacet
    # Kinda hacky to create user list here to send an invite. Instead of this,
    # I should implement a method in CW that will handle to invite stuff.
    @workspace.createUserList()
    query = { "profile.nickname": username }

    KD.remote.api.JAccount.one query, {}, (err, account) =>
      @workspace.userList.once "UserInvited", =>
        message    = "#{username} is successfully invited."
        if usernames.length > 1
          message += "You can invite only one person at a time. Try again for other users too."
        @botReply message

      @workspace.userList.once "UserInviteFailed", =>
        @botReply "Are you sure your friend's nickname is #{username}?"

      @workspace.userList.sendInvite account

  replyForWatch: (usernames) ->
    username = usernames.first
    return if usernames.length is 0 or usernames.first.trim is ""

    # TODO: fatihacet - I need to check username is valid and user is in session.
    @workspace.setWatchMode username
    message = """
      Ok. Now you started to watch #{username}.
      This means you will only be notified by #{username}'s changes.
      Type "watch nobody" to stop watching #{username} or type "watch username" to watch someone else.
    """
    @botReply message

  botReply: (message) ->
    messageData =
      message   : message
      by        :
        nickname: "teamwork"

    @sendMessage messageData, yes
