{CompositeDisposable} = require 'atom'

UI = require './ui'
Lines = require './provider/lines'
Search = require './provider/search'
Fold = require './provider/fold'
Input = require './input'
settings = require './settings'

module.exports =
  config: settings.config

  activate: ->
    @subscriptions = new CompositeDisposable
    settings.removeDeprecated()
    @input = new Input

    @subscribe atom.commands.add 'atom-workspace',
      'narrow:lines': => @lines()
      'narrow:fold': => new Fold(@getUI())
      'narrow:search': => @search()
      'narrow:search-current-project': => @searchCurrentProject()
      'narrow:focus': => @ui.focus()

  subscribe: (arg) ->
    @subscriptions.add arg

  lines: (word=null) ->
    ui = @getUI(initialInput: word)
    new Lines(ui)

  searchCurrentProject: (word) ->
    projects = null
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?
    for dir in atom.project.getDirectories() when dir.contains(editor.getPath())
      projects = [dir.getPath()]
      break

    unless projects?
      message = "#{editor.getPath()} not belonging to any project"
      atom.notifications.addInfo message, dismissable: true
      return
    @search(word, projects)

  search: (word=null, projects=atom.project.getPaths()) ->
    unless word?
      @input.readInput().then (input) =>
        @search(input, projects)

    return unless word
    ui = @getUI(initialKeyword: word)
    new Search(ui, {word, projects})

  deactivate: ->
    @subscriptions?.dispose()
    {@subscriptions} = {}

  getUI: (options={}) ->
    # [FIXME] make UI instance instance
    @ui = new UI(options)

  provideNarrow: ->
    getUI: @getUI.bind(this)
    search: @search.bind(this)
    lines: @lines.bind(this)

  consumeVim: ({getEditorState, observeVimStates}) ->
    isNarrowEditor = (vimState) ->
      vimState.editorElement.classList.contains('narrow')

    subscribe = @subscribe.bind(this)

    @subscribe observeVimStates (vimState) ->
      return unless isNarrowEditor(vimState)

      if settings.get('vmpStartInInsertModeForUI') and not vimState.isMode('insert')
        vimState.activate('insert')

      do (vimState) ->
        editor = vimState.editor
        subscribe vimState.modeManager.onDidActivateMode ({mode, submode}) ->
          if mode is 'insert' and editor.getCursorBufferPosition().row isnt 0
            editor.setCursorBufferPosition([0, Infinity])

    confirmSearch = -> # return search text
      editor = atom.workspace.getActiveTextEditor()
      vimState = getEditorState(editor)
      text = vimState.searchInput.editor.getText()
      vimState.searchInput.confirm()
      return text

    @subscribe atom.commands.add 'atom-text-editor.vim-mode-plus-search',
      'vim-mode-plus-user:narrow-lines-from-search': => @lines(confirmSearch())
      'vim-mode-plus-user:narrow-search': => @search(confirmSearch())
      'vim-mode-plus-user:narrow-search-current-project': => @searchCurrentProject(confirmSearch())
