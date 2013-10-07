# Base
Base   = require 'base'

# Models
Task    = require '../models/task'
List    = require '../models/list'
setting = require '../models/setting'

# Utils
Cookies = require '../utils/cookies'
CONFIG  = require '../utils/conf'

class Settings extends Base.Controller

  elements:
    '.disabler'           : 'disabler'
    '.language'           : 'language'
    '.username'           : 'username'
    '.clear-data'         : 'clearDataButton'
    '.week-start'         : 'weekStart'
    '.date-format'        : 'dateFormat'
    '.night-mode'         : 'nightMode'
    '#notify-time'        : 'notifyTime'
    '#notify-email'       : 'notifyEmail'
    '#notify-toggle'      : 'notifyToggle'
    '#notify-regular'     : 'notifyRegular'
    '.confirm-delete'     : 'confirmDelete'
    '.completed-duration' : 'completedDuration'
    '.clear-data-label'   : 'clearDataLabel'
    '#passwordreset'      : 'passwordreset'
    '.user-name'          : 'nameInput'
    '.user-email'         : 'emailInput'

  events:
    'click .login'         : 'login'
    'change input'         : 'save'
    'change select'        : 'save'
    'click .tabs li'       : 'tabSwitch'
    'click .clear-data'    : 'clearData'
    'click .night-mode'    : 'toggleNight'
    'click .language a'    : 'changeLanguage'
    'click .export-data'   : 'exportData'
    'click button.probtn'  : 'proUpgrade'
    'click #notify-toggle' : 'toggleNotify'
    'click .edit'          : 'editField'
    'click .save'          : 'saveField'

  constructor: ->
    # Spine.touchify(@events)

    super

    setting.on 'show',  @show
    setting.on 'login', @account

    @dateFormat.val         setting.dateFormat
    @completedDuration.val  setting.completedDuration
    @confirmDelete.prop     'checked', setting.confirmDelete
    @nightMode.prop         'checked', setting.night

    @setLanguage()

    unless setting.notifications is true and setting.isPro() is true
      @disabler.prop('disabled', true).addClass('disabled')
      @notifyToggle.prop 'checked', false

    @notifyEmail.prop 'checked', setting.notifyEmail
    @notifyTime.val setting.notifyTime
    @notifyRegular.val setting.notifyRegular

    @setupNotifications()

  # Highlight the current language
  setLanguage: (language = setting.language) =>
    $("[data-value=#{ language }").addClass('selected')

  account: =>
    # Show the proper account thing
    $('.account .signedout').hide()
    $('.account .signedin').show()

    @passwordreset.attr('action', 'http://' + CONFIG.server + '/forgot')
    @nameInput.val(setting.user_name)
    @emailInput.val(setting.user_email)

    # Forgive Me
    $('.account .user-language').val($('.language [data-value=' + setting.language + ']').text())

    @clearDataLabel.hide()
    @clearDataButton.text $.i18n._('Logout')

    $('.clearWrapper').css('text-align', 'center')

  proUpgrade: =>
    location.href = 'http://nitrotasks.com/pro?uid=' + setting.uid

  show: =>
    @el.modal()

  save: =>
    setting.username = @username.val()
    setting.weekStart = @weekStart.val()
    setting.dateFormat = @dateFormat.val()
    setting.completedDuration = @completedDuration.val()
    setting.confirmDelete =  @confirmDelete.prop 'checked'
    setting.night =  @nightMode.prop 'checked'
    setting.notifications =  @notifyToggle.prop 'checked'
    setting.notifyEmail =  @notifyEmail.prop 'checked'
    setting.notifyTime =  @notifyTime.val()
    setting.notifyRegular =  @notifyRegular.val()

    # Clear Notify Timeout
    try
      clearTimeout(settings.notifyTimeout)

    @setupNotifications()

  moveCompleted: =>
    List.forEach (list) ->
      list.moveCompleted()

  tabSwitch: (e) =>
    if $(e.target).hasClass('close')
      @el.modal('hide')
    else
      @el.find('.current').removeClass 'current'
      # One hell of a line of code, but it switches tabs. I'm amazing
      @el.find('div.' + $(e.target).addClass('current').attr('data-id')).addClass 'current'

  toggleNight: (e) =>
    if setting.isPro()
      $('html').toggleClass 'dark'
    else
      @nightMode.prop('checked', false)
      @el.modal('hide')
      $('.modal.proventor').modal('show')
      setting.night = false

  #FFFFUCKIT.
  editField: (e) ->
    if $(e.target).hasClass('name') or $(e.target).hasClass('email')
      text = $(e.target).text()
      @nameInput.prop('disabled', true)
      @emailInput.prop('disabled', true)
      $(e.target).parent().find('.save').hide()
      $(e.target).parent().find('.edit').text($.i18n._('Edit'))

      $(e.target).text(text)

      if $(e.target).text() is $.i18n._('Edit')
        $(e.target).text($.i18n._('Cancel'))

        if $(e.target).hasClass('name')
          $(e.target).parent().find('.name.save').show()
          @nameInput.prop('disabled', false).focus()
        else if $(e.target).hasClass('email')
          $(e.target).parent().find('.email.save').show()
          @emailInput.prop('disabled', false).focus()
      else
        $(e.target).parent().find('button.save').hide()
        $(e.target).text($.i18n._('Edit'))
        @nameInput.val(setting.user_name)
        @emailInput.val(setting.user_email)

    else if $(e.target).hasClass('language')
      $('.tabs li[data-id=language]').trigger('click')

  saveField: (e) ->
    # Hides Button
    $(e.target).hide()

    setting.userName = @nameInput.val()
    setting.userEmail = @emailInput.val()
    @nameInput.prop('disabled', true)
    @emailInput.prop('disabled', true)
    $(e.target).parent().find('button.edit').text($.i18n._('Edit'))

  setupNotifications: =>
    if setting.notifications and setting.isPro()

      now = Date.now()
      notifyTime = new Date()
      hour = setting.notifyTime

      notifyTime.setHours(hour)
      notifyTime.setMinutes(8)
      notifyTime.setSeconds(0)
      notifyTime.setMilliseconds(0)
      notifyTime = notifyTime.getTime()

      # If the time has passed, increment a day
      if notifyTime - now < 0
        notifyTime += 86400000

      @log "Notifying in: #{ ( notifyTime - now ) / 1000 } seconds"

      # console.log Task.all

      @notifyTimeout = setTimeout =>
        dueNumber = 0
        upcomingNumber = 0

        for task in Task.all()
          if task.date isnt '' and task.date isnt false and !task.completed
            # Number of Tasks that have due dates
            upcomingNumber++
            # Number of Tasks that are due
            if new Date(task.date) - new Date() < 0
              dueNumber++

        console.log {due: dueNumber, upcoming: upcomingNumber}

        if setting.notifyRegular is 'upcoming'
          notification = window.webkitNotifications.createNotification(
            'img/icon.png',
            'Nitro Tasks',
            'You have ' + upcomingNumber + ' tasks upcoming'
          ).show()
        else
          notification = window.webkitNotifications.createNotification(
            'img/icon.png',
            'Nitro Tasks',
            'You have ' + dueNumber + ' tasks due'
          ).show()
        @setupNotifications()
      , notifyTime - now

  logout: (e) ->
    Cookies.removeItem('uid')
    Cookies.removeItem('token')
    document.location.reload()

  clearData: =>
    if setting.token
      localStorage.clear()
      @logout()
    else
      $('.modal.settings').modal 'hide'
      $('.modal.delete').modal 'show'
      $('.modal.delete .true').on('click touchend', =>
        localStorage.clear()
        @logout()
        $('.modal.delete').modal 'hide'
        $('.modal.delete .true').off 'click touchend'
      )

      $('.modal.delete .false').on('click touchend', (e) ->
        $('.modal.delete').modal 'hide'
        $('.modal.delete .false').off 'click touchend'
      )

  exportData: ->
    @el.modal('hide')
    $('.modal.export').modal('show')
    $('.modal.export textarea').val Spine.Sync.exportData()

    $('.modal.export button').click ->
      Spine.Sync.importData($('.modal.export textarea').val()) if $(@).hasClass('true')
      $('.modal.export').modal('hide')
      $(@).off('click')

  changeLanguage: (e) =>
    # Pirate Speak is a Pro feature
    if $(e.target).attr('data-value') is 'en-pi' and !setting.isPro()
      @el.modal('hide')
      $('.modal.proventor').modal('show')
    else
      setting.language = $(e.target).attr('data-value')
      window.location.reload()

  login: =>
    $('.auth').fadeIn(300)
    @el.modal('hide')

  toggleNotify: =>
    if @notifyToggle.prop('checked')
      if setting.isPro()
        # Enable Checkboxes
        window.webkitNotifications.requestPermission ->
          console.log('Hello')
          if window.webkitNotifications.checkPermission() is 0
            console.log('Hello')
            $('.disabler').prop('disabled', false).removeClass('disabled')

          else
            setting.notifications = false
            alert 'You\'ll need to open your browser settings and allow notifications for app.nitrotasks.com'

      else
        @notifyToggle.prop('checked', false)
        # Because it gets set as true for a stupid reason
        setting.notifications = false
        @el.modal('hide')
        $('.modal.proventor').modal('show')
    else
      # Disable Checkboxes
      @disabler.prop('disabled', true).addClass('disabled')

module.exports = Settings
