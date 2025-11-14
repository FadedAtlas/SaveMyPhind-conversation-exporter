import browser from 'webextension-polyfill'

console.log "Background script loaded"

# Manage installation
browser.runtime.onInstalled..addListener do(details)
	if details.reason === 'install'
		console.log "Extension installed"
		# Initialize the storage
		browser.storage.sync.set {
			initialized: true
			installDate: Date.now!
		}
	elif details.reason === 'update'
		console.log "Extension updated"

# On icon click
browser.action.onClicked.addListener do(currentTabInfos\(browser.tabs.tab))
	console.info("Icon clicked")

	# --- Launch scapping ---
	# 1. Get webpage infos
	const extractablePage\(String|false) = checkWebpageExtractable currentTabInfos
	return if !extractablePage
	const pageInfos = {
		extractablePage
		...currentTabInfos
	}
	console.log "HERE!", pageInfos

	# 2. Get webpage extraction config
	const pageConfig\Object = getWebpageExtractionConfig extractablePage
	console.log pageConfig

	# 3. Get user extraction config
	const userConfig\Object = getUserConfig!

	# 4. Extract webpage content
	const pageContent\Array<HTMLElement> = extractWebpageContent pageConfig, userConfig

	# 5. Format content
	const outputContent\Object<key:String> = formatContent pageContent, userConfig

	# 6. Generate output
	generateOutput outputContent

const EXTRACTION_ALLOWED_PAGES =
	"PhindSearch": "www.phind.com/search"
	"Perplexity": "www.perplexity.ai/search"
	"PerplexityPages": "www.perplexity.ai/page"
	"MaxAIGoogle": "www.google.com/search"
	"ChatGPT": "chatgpt.com/c"
	"ChatGPTShare": "chatgpt.com/share"
	"ChatGPTBots": "chatgpt.com/g"
	"ChatGPTSignedOut": "chatgpt.com"
	"ClaudeChat": "claude.ai/chat"
	"ClaudeShare": "claude.ai/share"


def checkWebpageExtractable pageInfos
	const webpageUrl = pageInfos.url.split("https://")[1]

	for own pageName, pageUrl of EXTRACTION_ALLOWED_PAGES
		if webpageUrl..startsWith pageUrl
			return pageName
	return false


def getWebpageExtractionConfig pageConfigName
	return {}

def getUserConfig
	return {}

def extractWebpageContent pageConfig, userConfig
	return []

def formatContent pageContent, userConfig
	return {}

def generateOutput outputContent
	console.log "EXTRACTION!"