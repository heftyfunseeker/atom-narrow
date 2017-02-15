_ = require 'underscore-plus'
ProviderBase = require './provider-base'
{requireFrom} = require '../utils'
{Point} = require 'atom'
path = require 'path'

TagReader = requireFrom('symbols-view', 'tag-reader')
SymbolsView = requireFrom('symbols-view', 'symbols-view')
getTagLine = SymbolsView::getTagLine

module.exports =
class ProjectSymbols extends ProviderBase
  includeHeaderGrammar: true
  showLineHeader: true
  supportCacheItems: true # manage manually
  items: null

  @cache: null

  itemForTag: (tag) ->
    {directory, file, lineNumber, name} = tag
    point = getTagLine(tag)
    if point?
      {
        point: point
        filePath: path.join(directory, file)
        text: name
      }

  stop: ->
    @loadTagsTask?.terminate()

  cacheItems: (items) ->
    @constructor.cachedItems = items

  getCachedItems: ->
    @constructor.cachedItems

  start: ->
    @stop()

    # excludeKinds = ['v']
    kindOfInterests = 'cfm'

    new Promise (resolve) =>
      cache = @getCachedItems()
      if cache?
        return resolve(cache)

      @loadTagsTask = TagReader.getAllTags (tags) =>
        items = tags
          .filter (tag) -> tag.kind in kindOfInterests
          .map(@itemForTag)
          .filter (item) -> item?
          .sort (a, b) -> a.point.compare(b.point)
        items = _.uniq items, (item) -> item.filePath + item.text
        items = @getItemsWithHeaders(items)
        @cacheItems(items)
        resolve(items)

  getItems: ->
    @start()

  filterItems: (items, filterSpec) ->
    @getItemsWithoutUnusedHeader(super)
