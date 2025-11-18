import browser from 'webextension-polyfill'
import {htmlToMarkdown} from "./html-to-md"
import {EXTRACTION_CONFIGS} from "./data/extractionConfigs"
import {EXTRACTION_ALLOWED_PAGES} from "./data/extractionAllowedPages.imba"

# --- Launch scraping ---
export def launchScraping currentTabInfos
	# 1. Get webpage infos
	const extractablePage\(String|false) = checkWebpageExtractable currentTabInfos
	return if !extractablePage
	const pageInfos = {
		extractablePage
		...currentTabInfos
	}
	# console.log "HERE!", pageInfos

	# 2. Get webpage extraction config
	const pageConfig\Object = getWebpageExtractionConfig extractablePage
	# console.log pageConfig

	# 3. Get user extraction config
	const userConfig\Object = await getUserConfig!

	# 4. Extract webpage content
	const pageContent\Array<HTMLElement> = await extractWebpageContent pageInfos, pageConfig, userConfig
	# console.log pageContent
	
	# 5. Format content
	const outputContent\Object<String:String> = formatContent pageInfos, pageContent, userConfig, pageConfig

	# 6. Generate output
	generateOutput pageInfos, outputContent, pageContent, userConfig, pageConfig

export def checkWebpageExtractable\(String|false) pageInfos
	const webpageUrl = pageInfos.url.split("https://")[1]
	for own pageName, pageUrl of EXTRACTION_ALLOWED_PAGES
		if webpageUrl.startsWith pageUrl
			return pageName
	return false

export def getWebpageExtractionConfig\{} pageConfigName
	return EXTRACTION_CONFIGS[pageConfigName] || {}

export def getUserConfig
	# Get user preferences from storage
	const result = await browser.storage.sync.get([
		'filenameTemplate'
		'webhookUrl'
		'outputOptions'
	])
	
	return {
		includePageTitle: true
		includeSources: true
		formatMarkdown: true
		filenameTemplate: result..filenameTemplate || '%Y-%M-%D_%h-%m-%s_%W_%T'
		webhookUrl: result..webhookUrl || ''
		outputOptions: result..outputOptions || {
			localDownload: true
			webhook: false
		}
	}

export def extractWebpageContent\Promise<{html: string, title: string, sections: Array}> pageInfos, pageConfig, userConfig
	# Ensure the content-script is loaded
	const isLoaded = await ensureContentScriptLoaded(pageInfos.id)
	if !isLoaded
		console.error "Cannot load content script"
		return { html: '', title: '', sections: [] }
	
	const response\(
		{ success: boolean, data: { html: string, title: string, sections: Array }} | { success: boolean } | any
	) = await browser.tabs.sendMessage(pageInfos.id, {
		type: 'EXTRACT_CONTENT'
		pageConfig
		pageInfos
		userConfig
	}).catch do(error)
		console.error "Failed to communicate with content script:", error
		return { success: false }
	
	if response..success then return response..data
	else 
		console.error "Content script error:", response..error
		return { html: '', title: '', sections: [] }

def formatFilename pageInfos, pageContent, userConfig, pageConfig
	# console.log userConfig
	let template = userConfig..filenameTemplate || '%Y-%M-%D_%h-%m-%s_%W_%T'
	const now = new Date()
	
	# Extract the page title (first 60 characters)
	const pageTitle = pageContent.title || 'export'
	const truncatedTitle = pageTitle.slice(0, 60).replace(/[^a-zA-Z0-9]/g, '_')
	
	# Extract domain name
	const domainName = pageConfig..domainName || pageInfos.url.split('/')[2]
	
	# Replace placeholders
	const replacements = {
		'%W': domainName.replace(/[^a-zA-Z0-9]/g, '_')
		'%H': pageInfos.url.split('/')[2]
		'%T': truncatedTitle
		'%t': now.getTime().toString()
		'%Y': now.getFullYear().toString()
		'%M': (now.getMonth() + 1).toString().padStart(2, '0')
		'%D': now.getDate().toString().padStart(2, '0')
		'%h': now.getHours().toString().padStart(2, '0')
		'%m': now.getMinutes().toString().padStart(2, '0')
		'%s': now.getSeconds().toString().padStart(2, '0')
	}
	
	for own placeholder, value of replacements
		template = template.replace(new RegExp(placeholder, 'g'), value)
	
	return template

# Helper function to clean and truncate title
def cleanTitle title, maxLength = 100
	# Remove line breaks and extra whitespace
	let cleaned = title.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim()
	
	# Truncate if too long
	if cleaned.length > maxLength
		cleaned = cleaned.slice(0, maxLength) + '...'
	
	return cleaned

export def formatContent pageInfos, pageContent, userConfig, pageConfig
	let output = ""
	
	# Add the page title (cleaned and limited)
	if userConfig.includePageTitle and pageContent.title
		const cleanedTitle = cleanTitle(pageContent.title, 100)
		output += "# " + cleanedTitle + "\n\n"
	
	# Add metadata
	const source = if pageConfig..domainName then "[{pageConfig..domainName}]({pageInfos.url})" else "{pageInfos.url}"
	output += `Source: {source}\n`
	output += `Extracted: {new Date().toISOString()}\n`
	output += `🚀 Exported with [Save my Chatbot](https://save.hugocolin.com)!\n`
	output += "\n---\n\n"
	
	# Format the content according to the type of extraction
	if pageContent.sections and pageContent.sections.length > 0
		# Content structured by sections
		for section in pageContent.sections
			if section.type === 'message'
				output += formatMessage(section, userConfig)
			elif section.type === 'search-qa'
				output += formatSearchQA(section, userConfig)
			elif section.type === 'article'
				output += formatArticle(section, userConfig)
			else
				# Generic content
				output += htmlToMarkdown(section.html) + "\n\n"
	else
		# Fallback: all the HTML
		output += htmlToMarkdown(pageContent.html)
	
	return output

def formatMessage section, userConfig
	let output = ""
	output += "## " + (section.role || "Unknown") + "\n\n"
	output += htmlToMarkdown(section.content) + "\n"
	
	if section.inputs and section.inputs.length > 0
		output += "\n##### Inputs:\n"
		for input in section.inputs
			output += `- {input}\n`
	
	if section.sources and section.sources.length > 0 and userConfig.includeSources
		output += "\n##### Sources:\n"
		for source in section.sources
			output += `- [{source.title || source.url}]({source.url})\n`
	
	output += "\n"
	return output

def formatSearchQA section, userConfig
	let output = ""
	
	if section.question
		output += "## Message\n\n"
		output += htmlToMarkdown(section.question) + "\n\n"
	
	# if section.model
	# 	output += `*Model: {section.model}*\n\n`
	
	if section.answer
		output += "## Answer\n\n"
		output += htmlToMarkdown(section.answer) + "\n\n"
	
	if section.sources and section.sources.length > 0 and userConfig.includeSources
		output += "## Sources\n\n"
		for source in section.sources
			output += `- [{source.title || source.url}]({source.url})\n`
		output += "\n"
	
	return output

def formatArticle section, userConfig
	let output = ""
	output += htmlToMarkdown(section.content) + "\n\n"
	
	if section.sources and section.sources.length > 0 and userConfig.includeSources
		output += "## References\n\n"
		for source in section.sources
			output += `- [{source.title || source.url}]({source.url})\n`
		output += "\n"
	
	return output

def sendToWebhook webhookUrl, content, filename
	try
		const formData = new FormData()
		const blob = new Blob([content], { type: 'text/markdown' })
		formData.append('file', blob, filename + '.md')
		
		const response = await fetch(webhookUrl, {
			method: 'POST'
			body: formData
			# Note: Do not set Content-Type manually
			# The browser will do it automatically with the correct boundary
		})
		
		if response.ok
			console.log "File successfully sent to webhook"
			return { success: true }
		else
			console.error "Webhook request failed:", response.status
			return { success: false, error: "HTTP {response.status}" }
	catch error
		console.error "Error sending the file to the webhook:", error
		return { success: false, error: error.message }

def sendJsonToWebhook webhookUrl, content, filename
	try
		const response = await fetch(webhookUrl, {
			method: 'POST'
			headers: {
				'Content-Type': 'application/json'
			}
			body: JSON.stringify({
				filename: filename
				content: content
				timestamp: new Date().toISOString()
			})
		})
		
		if response.ok
			console.log "Content sent to webhook successfully"
			return { success: true }
		else
			console.error "Webhook request failed:", response.status
			return { success: false, error: "HTTP {response.status}" }
	catch error
		console.error "Failed to send to webhook:", error
		return { success: false, error: error.message }

export def generateOutput pageInfos, outputContent, pageContent, userConfig, pageConfig
	# console.log "EXTRACTION!", outputContent
	# console.log userConfig, userConfig
	
	# Generate a filename based on the template
	const filename = formatFilename(pageInfos, pageContent, userConfig, pageConfig)
	
	# Ensure that the content script is loaded before export
	await ensureContentScriptLoaded(pageInfos.id)
	
	# Manage the outputs according to the options
	const results = {
		localDownload: null
		webhook: null
	}
	# console.log "userConf", userConfig
	# Local download
	if userConfig.outputOptions.localDownload
		const response = await browser.tabs.sendMessage(pageInfos.id, {
			type: 'EXPORT_CONTENT'
			outputContent
			filename
		}).catch do(error)
			console.error "Failed to communicate with content script:", error
			return { success: false, error: error.message }
		
		results.localDownload = response
	
	# Webhook
	if userConfig.outputOptions.webhook and userConfig.webhookUrl
		results.webhook = await sendToWebhook(userConfig.webhookUrl, outputContent, filename)
	
	return results

# Checks if the content script is loaded and injects it if necessary
def ensureContentScriptLoaded tabId
	try
		# Try to ping the content script
		await browser.tabs.sendMessage(tabId, { type: 'PING' })
		return true
	catch error
		console.log "Content script not loaded, injecting..."
		
		try
			# Inject the content script manually
			await browser.scripting.executeScript({
				target: { tabId: tabId }
				files: ['content.js']
			})
			
			# Wait a little while for the script to initialize
			await new Promise(do(resolve) setTimeout(resolve, 100))
			
			console.log "Content script injected successfully"
			return true
		catch injectError
			console.error "Failed to inject content script:", injectError
			return false