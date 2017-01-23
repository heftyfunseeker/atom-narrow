_ = require 'underscore-plus'
{Point, CompositeDisposable, Emitter} = require 'atom'
{
  saveEditorState
  padStringLeft
} = require '../utils'
UI = require '../ui'
settings = require '../settings'
Input = null

module.exports =
class ProviderBase
  wasConfirmed: false
  boundToEditor: false
  includeHeaderGrammarRules: false

  supportDirectEdit: false

  indentTextForLineHeader: ""
  showLineHeader: true

  getName: ->
    @constructor.name

  invalidateCachedItem: ->
    @items = null

  getDashName: ->
    _.dasherize(@getName())

  refresh: ->
    @items = null
    @ui.refresh().then =>
      @ui.syncToProviderEditor()

  initialize: ->
    # to override

  checkReady: ->
    Promise.resolve(true)

  constructor: (@options={}) ->
    @subscriptions = new CompositeDisposable
    @editor = atom.workspace.getActiveTextEditor()
    @editorElement = @editor.element
    @pane = atom.workspace.paneForItem(@editor)
    @restoreEditorState = saveEditorState(@editor)
    @emitter = new Emitter

    @ui = new UI(this, {input: @options.uiInput})

    if @boundToEditor
      @subscribe @editor.onDidStopChanging(@refresh.bind(this))

    @checkReady().then (ready) =>
      if ready
        @initialize()
        @ui.start()

  subscribe: (args...) ->
    @subscriptions.add(args...)

  getFilterKey: ->
    "text"

  filterItems: (items, regexps) ->
    filterKey = @getFilterKey()
    for regexp in regexps
      items = items.filter (item) ->
        if (text = item[filterKey])?
          regexp.test(text)
        else
          true # items without filterKey is always displayed.
    items

  destroy: ->
    @subscriptions.dispose()
    if @editor.isAlive() and not @wasConfirmed
      @restoreEditorState()
    {@editor, @editorElement, @subscriptions} = {}

  confirmed: ({point}) ->
    @wasConfirmed = true
    return unless point?
    point = Point.fromObject(point)

    newPoint = @adjustPoint?(point)
    if newPoint?
      @editor.setCursorBufferPosition(newPoint, autoscroll: false)
    else
      @editor.setCursorBufferPosition(point, autoscroll: false)
      @editor.moveToFirstCharacterOfLine()

    @pane.activate()
    @pane.activateItem(@editor)

    @editor.scrollToBufferPosition(point, center: true)

    return {@editor, point}

  # View
  # -------------------------
  viewForItem: (item) ->
    if item.header?
      item.header
    else
      if @showLineHeader
        @getViewTextWithLineHeaderForItem(item)
      else
        item.text

  getViewTextWithLineHeaderForItem: (item, editor) ->
    @getLineHeaderForItem(item, editor) + item.text

  # Unless items didn't have maxLineTextWidth field, detect last line from editor.
  getLineHeaderForItem: ({text, point, maxLineTextWidth}, editor=@editor) ->
    maxLineTextWidth ?= String(editor.getLastBufferRow() + 1).length
    @indentTextForLineHeader + padStringLeft(String(point.row + 1), maxLineTextWidth) + ':'

  # Direct Edit
  # -------------------------
  getChangeSet: (states) ->
    changes = []
    for {newText, item} in states
      lineHeaderLength = @getLineHeaderForItem(item).length
      newText = newText[lineHeaderLength...]
      if newText isnt item.text
        changes.push({newText, item})
    changes

  updateRealFile: (states) ->
    changes = @getChangeSet(states)
    return unless changes.length

    @pane.activate()
    if @boundToEditor
      @applyChangeSet(@editor, changes)
    else
      changesByFilePath =  _.groupBy(changes, ({item}) -> item.filePath)
      for filePath, changes of changesByFilePath
        # CRITICAL: protect `changes` replaced by outer variable.
        do (filePath, changes) =>
          atom.workspace.open(filePath, activateItem: false).then (editor) =>
            @applyChangeSet(editor, changes)

  needSaveAfterDirectEdit: ->
    param = @getName() + 'SaveAfterDirectEdit'
    settings.get(param)

  applyChangeSet: (editor, changes) ->
    editor.transact ->
      for {newText, item} in changes
        range = editor.bufferRangeForBufferRow(item.point.row)
        editor.setTextInBufferRange(range, newText)
    editor.save() if @needSaveAfterDirectEdit()

  # Helpers
  # -------------------------
  readInput: ->
    Input ?= require '../input'
    new Input().readInput()
