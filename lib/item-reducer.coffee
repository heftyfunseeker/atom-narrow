# item presenting
# -------------------------
_ = require 'underscore-plus'
path = require('path')

# Helper
# -------------------------
isNormalItem = (item) -> not item.skip

getLineHeaderForItem = (point, maxLineWidth, maxColumnWidth) ->
  lineText = String(point.row + 1)
  padding = " ".repeat(maxLineWidth - lineText.length)
  lineHeader = "#{padding}#{lineText}"
  if maxColumnWidth?
    columnText = String(point.column + 1)
    padding = " ".repeat(maxColumnWidth - columnText.length)
    lineHeader = "#{lineHeader}:#{padding}#{columnText}"
  lineHeader + ": "

# Reducer
# -------------------------
# Purpose of reducer is build final items through different filter.
# Reducer is filter, which mutate state and mutated state is passed to next reducer.
# All reducers take single state object as argument
# If reducer return object, that object is merged to state and passed to next reducer
# If reducer return nothing, original state is passed to next reducer.
injectLineHeader = (state) ->
  return null if state.hasCachedItems

  normalItems = state.items.filter(isNormalItem)

  toRow = (item) -> item.point.row
  byMax = (max, value) -> Math.max(max, value)
  maxRow = normalItems.map(toRow).reduce(byMax, 0)
  maxLineWidth = String(maxRow + 1).length

  if state.showColumn
    toColumn = (item) -> item.point.column
    maxColumn = normalItems.map(toColumn).reduce(byMax, 0)
    maxColumnWidth = Math.max(String(maxColumn).length, 2)
    console.log maxColumn

  for item in normalItems
    item._lineHeader = getLineHeaderForItem(item.point, maxLineWidth, maxColumnWidth)

  return null

injectHeaderAndProjectName = (state) ->
  return null if state.hasCachedItems

  {projectHeadersInserted, fileHeadersInserted} = state

  items = []
  for item in state.items
    if item.projectName
      projectName = item.projectName
    else
      projectPath = atom.project.relativizePath(item.filePath)[0]
      projectName = path.basename(projectPath)
      item.projectName = projectName

    if projectName not of projectHeadersInserted
      header = "# #{projectName}"
      items.push({header, projectName, projectHeader: true, skip: true})
      projectHeadersInserted[projectName] = true

    filePath = item.filePath
    if filePath not of fileHeadersInserted
      state.onFilePathChange?()
      header = "## " + atom.project.relativize(filePath)
      items.push({header, projectName, filePath, fileHeader: true, skip: true})
      fileHeadersInserted[filePath] = true

    items.push(item)

  return {projectHeadersInserted, fileHeadersInserted, items}

collectBeforeFiltered = (state) ->
  {allItems: state.allItems.concat(state.items)}

removeUnusedHeader = (state) ->
  normalItems = state.items.filter(isNormalItem)
  filePaths = _.uniq(_.pluck(normalItems, "filePath"))
  projectNames = _.uniq(_.pluck(normalItems, "projectName"))

  items = state.items.filter (item) ->
    if item.header?
      if item.projectHeader?
        item.projectName in projectNames
      else if item.filePath?
        item.filePath in filePaths
      else
        true
    else
      true
  return {items}

# reducers =
module.exports = {
  injectLineHeader
  injectHeaderAndProjectName
  collectBeforeFiltered
  removeUnusedHeader
}
