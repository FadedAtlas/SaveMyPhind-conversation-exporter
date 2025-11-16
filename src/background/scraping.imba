import browser from 'webextension-polyfill'
import {htmlToMarkdown} from "./html-to-md"
import {EXTRACTION_CONFIGS} from "./extractionConfigs"

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
	return EXTRACTION_CONFIGS[pageConfigName] || {}

export def getUserConfig
	# Récupère les préférences utilisateur depuis le storage
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
	console.log userConfig
	let template = userConfig..filenameTemplate || '%Y-%M-%D_%h-%m-%s_%W_%T'
	const now = new Date()
	
	# Extraire le titre de la page (premiers 60 caractères)
	const pageTitle = pageContent.title || 'export'
	const truncatedTitle = pageTitle.slice(0, 60).replace(/[^a-zA-Z0-9]/g, '_')
	
	# Extraire le nom du domaine
	const domainName = pageConfig..domainName || pageInfos.url.split('/')[2]
	
	# Remplacer les placeholders
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

export def formatContent pageInfos, pageContent, userConfig, pageConfig
	let output = ""
	
	# Ajouter le titre de la page
	if userConfig.includePageTitle and pageContent.title
		output += "# " + pageContent.title + "\n\n"
	
	# Ajouter les métadonnées
	const source = if pageConfig..domainName then "[{pageConfig..domainName}]({pageInfos.url})" else "{pageInfos.url}"
	output += `Source: {source}\n`
	output += `Extracted: {new Date().toISOString()}\n`
	output += `🚀 Exported with [Save my Chatbot](https://save.hugocolin.com)!\n`
	output += "\n---\n\n"
	
	# Formatter le contenu selon le type d'extraction
	if pageContent.sections and pageContent.sections.length > 0
		# Contenu structuré par sections
		for section in pageContent.sections
			if section.type === 'message'
				output += formatMessage(section, userConfig)
			elif section.type === 'search-qa'
				output += formatSearchQA(section, userConfig)
			elif section.type === 'article'
				output += formatArticle(section, userConfig)
			else
				# Contenu générique
				output += htmlToMarkdown(section.html) + "\n\n"
	else
		# Fallback: tout le HTML
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
		output += "## Question\n\n"
		output += htmlToMarkdown(section.question) + "\n\n"
	
	if section.model
		output += `*Model: {section.model}*\n\n`
	
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
	console.log "EXTRACTION!", outputContent
	console.log userConfig, userConfig
	
	# Générer un nom de fichier basé sur le template
	const filename = formatFilename(pageInfos, pageContent, userConfig, pageConfig)
	
	# Gérer les sorties selon les options
	const results = {
		localDownload: null
		webhook: null
	}
	console.log "userConf", userConfig
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