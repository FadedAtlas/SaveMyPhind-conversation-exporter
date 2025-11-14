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

	# Launch scapping
	const webpageInfos\Object = currentTabInfos
	const extractablePage\(String|false) = checkWebpageExtractable webpageInfos
	return if !extractablePage
	console.log "HERE!"
	# const siteConfig\Object = getSiteConfig webpageInfos
	# console.log siteConfig
	# const userConfig\Object = getUserConfig!
	# const siteContent\Array<HTMLElement> = extractSiteContent siteConfig userConfig
	# const outputContent\Array<String> = formatContent siteConfig userConfig.format
	# generateOutput outputContent

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


def checkWebpageExtractable webpageInfos
	# console.log "nice!", webpageInfos.url
	# console.log EXTRACTION_ALLOWED_PAGES

	const webpageUrl = webpageInfos.url.split("https://")[1]

	for own pageName, pageUrl of EXTRACTION_ALLOWED_PAGES
		if webpageUrl..startsWith pageUrl
			return pageName
	return false