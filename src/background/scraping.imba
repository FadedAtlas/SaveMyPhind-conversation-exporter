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

export def getUserConfig\{}
	# Peut être étendu pour récupérer les préférences utilisateur depuis le storage
	return {
		includePageTitle: true
		includeSources: true
		formatMarkdown: true
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

export def generateOutput pageInfos, outputContent
	console.log "EXTRACTION!", outputContent
	
	# Générer un nom de fichier basé sur le titre de la page
	const pageTitle = outputContent.split('\n')[0].replace(/^# /, '').trim()
	const filename = pageTitle || 'export'
	
	const response = await browser.tabs.sendMessage(pageInfos.id, {
		type: 'EXPORT_CONTENT'
		outputContent
		filename
	}).catch do(error)
		console.error "Failed to communicate with content script:", error