import browser from 'webextension-polyfill'

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


export def checkWebpageExtractable\(String|false) pageInfos
	const webpageUrl = pageInfos.url.split("https://")[1]

	for own pageName, pageUrl of EXTRACTION_ALLOWED_PAGES
		if webpageUrl.startsWith pageUrl
			return pageName
	return false


export def getWebpageExtractionConfig\{} pageConfigName
	return {}

export def getUserConfig\{}
	return {}

export def extractWebpageContent\Promise<{html: string, title: string}> pageInfos, pageConfig, userConfig
	const response\(
		{ success: boolean, data: { html: string, title: string }} | { success: boolean } | any
	) = await browser.tabs.sendMessage(pageInfos.id, {
		type: 'EXTRACT_CONTENT'
		pageConfig
		pageInfos
	}).catch do(error)
		console.error "Failed to communicate with content script:", error
		return { success: false }
	
	if response..success then return response..data
	else 
		console.error "Content script error:", response..error
		return { html: '', title: '' }

export def formatContent pageInfos, pageContent, userConfig
	console.log pageContent
	return pageContent.html

export def generateOutput pageInfos, outputContent
	console.log "EXTRACTION!", outputContent
	const response = await browser.tabs.sendMessage(pageInfos.id, {
		type: 'EXPORT_CONTENT'
		outputContent
	}).catch do(error)
		console.error "Failed to communicate with content script:", error