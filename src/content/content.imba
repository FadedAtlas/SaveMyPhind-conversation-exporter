import browser from 'webextension-polyfill'

console.log "Content script loaded"

# Utilitaires d'extraction
def getElementText element
	return element..textContent..trim() || ""

def getElementHTML element
	return element..innerHTML || ""

def waitForElement selector, timeout = 5000
	return new Promise do(resolve)
		const element = document.querySelector(selector)
		if element
			resolve(element)
			return
		
		const observer = new MutationObserver do
			const el = document.querySelector(selector)
			if el
				observer.disconnect()
				resolve(el)
		
		observer.observe(document.body, {
			childList: true
			subtree: true
		})
		
		setTimeout(&, timeout) do
			observer.disconnect()
			resolve(null)

def extractBySelector selector, scope = 'document'
	const root = if scope === 'document' then document else scope
	if typeof root === 'string'
		return null
	
	const element = root.querySelector(selector)
	return element

def extractAllBySelector selector, scope = 'document'
	const root = if scope === 'document' then document else scope
	if typeof root === 'string'
		return []
	
	return Array.from(root.querySelectorAll(selector))

# Extracteurs par type de page
def extractMessageList config
	const contentElements = extractAllBySelector(config.contentSelector)
	const sections = []
	
	for contentElement in contentElements
		const section = extractMessage(contentElement, config.messageConfig)
		if section
			sections.push(section)
	
	return sections

def extractMessage element, messageConfig
	try
		let role = null
		let content = null
		
		# Déterminer le rôle
		if messageConfig.roleAttribute
			const roleElement = element.querySelector(messageConfig.roleSelector)
			const roleAttr = roleElement..getAttribute(messageConfig.roleAttribute)
			role = messageConfig.roles[roleAttr] || roleAttr || "Message"
		elif messageConfig.streamingIndicator and element.closest(messageConfig.streamingIndicator)
			role = messageConfig.roles.assistant
		elif messageConfig.userSelector and element.matches(messageConfig.userSelector)
			role = messageConfig.roles.user
		elif messageConfig.assistantSelector and element.matches(messageConfig.assistantSelector)
			role = messageConfig.roles.assistant
		else
			role = "Message"
		
		# Extraire le contenu
		const contentElement = element.querySelector(messageConfig.contentSelector) || element
		content = getElementHTML(contentElement)
		
		# Extraire les inputs si présents (pour Claude)
		let inputs = []
		if messageConfig.inputsSelector
			const inputElements = element.querySelectorAll(messageConfig.inputsSelector)
			inputs = Array.from(inputElements).map do(input)
				return getElementText(input.querySelector('.shrink.flex'))
		
		return {
			type: 'message'
			role: role
			content: content
			inputs: inputs
		}
	catch error
		console.error "Error extracting message:", error
		return null

def extractSearchSections config
	const contentElements = extractAllBySelector(config.contentSelector)
	const sections = []
	
	for contentElement in contentElements
		const section = extractSearchSection(contentElement, config.sectionConfig)
		if section
			sections.push(section)
	
	return sections

def extractSearchSection element, sectionConfig
	try
		const question = element.querySelector(sectionConfig.userQuestionSelector)
		const answer = element.querySelector(sectionConfig.aiAnswerSelector)
		const model = if sectionConfig.aiModelSelector then element.querySelector(sectionConfig.aiModelSelector) else null
		
		return {
			type: 'search-qa'
			question: if question then getElementHTML(question) else null
			answer: if answer then getElementHTML(answer) else null
			model: if model then getElementText(model) else null
		}
	catch error
		console.error "Error extracting search section:", error
		return null

def extractArticleSections config
	const contentElements = extractAllBySelector(config.contentSelector)
	const sections = []
	
	for contentElement in contentElements
		sections.push({
			type: 'article'
			content: getElementHTML(contentElement)
		})
	
	return sections

def extractFullPage config
	return [{
		type: 'full-page'
		html: document.body.innerHTML
	}]

def extractSources contentElement, sourcesConfig
	const sources = []
	
	if not sourcesConfig or not sourcesConfig.selectors
		return sources
	
	for selectorConfig in sourcesConfig.selectors
		if selectorConfig.extractionType === 'list'
			const scope = if selectorConfig.scope === 'content' then contentElement else document
			const sourceElements = extractAllBySelector(selectorConfig.selector, scope)
			
			for sourceElement in sourceElements
				const link = sourceElement.querySelector('a') || sourceElement
				sources.push({
					url: link.href || ''
					title: getElementText(link)
				})
		
		elif selectorConfig.extractionType === 'tile-list'
			const scope = if selectorConfig.scope === 'content' then contentElement else document
			const sourceElements = extractAllBySelector(selectorConfig.selector, scope)
			
			for sourceElement in sourceElements
				const link = sourceElement.querySelector('a')
				if link
					sources.push({
						url: link.href || ''
						title: getElementText(sourceElement)
					})
	
	return sources

# Fonction principale d'extraction
def performExtraction pageConfig, userConfig
	try
		# Extraire le titre
		const titleElement = extractBySelector(pageConfig.pageTitle.selector)
		const title = if titleElement then getElementText(titleElement) else document.title
		
		# Extraire le contenu selon le type
		let sections = []
		
		if pageConfig.extractionType === 'message-list'
			sections = extractMessageList(pageConfig)
		elif pageConfig.extractionType === 'search-sections'
			sections = extractSearchSections(pageConfig)
		elif pageConfig.extractionType === 'articles-sections'
			sections = extractArticleSections(pageConfig)
		elif pageConfig.extractionType === 'full-page'
			sections = extractFullPage(pageConfig)
		else
			# Fallback: extraire tout le contenu
			const contentElements = extractAllBySelector(pageConfig.contentSelector)
			sections = contentElements.map do(el)
				return { type: 'generic', html: getElementHTML(el) }
		
		# Extraire les sources si configuré
		if userConfig.includeSources and pageConfig.sourcesExtraction
			for section in sections
				const contentElement = document.querySelector(pageConfig.contentSelector)
				if contentElement
					section.sources = extractSources(contentElement, pageConfig.sourcesExtraction)
		
		return {
			success: true
			data: {
				html: document.body.innerHTML
				title: title
				sections: sections
			}
		}
	catch error
		console.error "Extraction error:", error
		return {
			success: false
			error: error.message
		}

# Fonction de téléchargement
def legacyDownload text\String, filename\String="Export"
	const blob = new Blob([text], { type: 'text/markdown' })
	const url = URL.createObjectURL(blob)
	const a = document.createElement('a')
	a.href = url
	a.download = filename + '.md'
	document.body.appendChild(a)
	a.click()
	document.body.removeChild(a)
	URL.revokeObjectURL(url)

# Écoute des messages
browser.runtime.onMessage.addListener do(message, sender, sendResponse)
	console.log "Content script received message:", message
	
	if message.type === 'EXTRACT_CONTENT'
		try
			const result = performExtraction(message.pageConfig, message.userConfig)
			sendResponse(result)
		catch error
			console.error "Error during extraction:", error
			sendResponse({
				success: false
				error: error.message
			})
		
		# Return true to indicate we'll send response asynchronously
		return true
	
	if message.type === 'EXPORT_CONTENT'
		const filename = message.filename || 'Export'
		legacyDownload(message.outputContent, filename)
		sendResponse({ success: true })
		return true
	
	return false