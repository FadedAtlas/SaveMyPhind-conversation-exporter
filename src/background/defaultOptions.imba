import browser from 'webextension-polyfill'

# Fonction pour réinitialiser les options par défaut
export def resetToDefaultOptions
	try
		const defaultSettings = {
			filenameTemplate: '%Y-%M-%D_%h-%m-%s_%W_%T'
			webhookUrl: ''
			outputOptions: {
				localDownload: true
				webhook: false
			}
		}
		
		await browser.storage.sync.set(defaultSettings)
		console.log "Settings reset to defaults"
		return { success: true, settings: defaultSettings }
	catch error
		console.error "Error resetting to default options:", error
		return { success: false, error: error.message }

# Fonction pour valider les paramètres utilisateur
export def validateUserConfig config
	const errors = []
	
	# Valider le template de nom de fichier
	if config.filenameTemplate
		const validPlaceholders = ['%W', '%H', '%T', '%t', '%Y', '%M', '%D', '%h', '%m', '%s']
		const invalidChars = /[<>:"/\\|?*]/g
		
		if invalidChars.test(config.filenameTemplate)
			errors.push("Filename template contains invalid characters")
	
	# Valider l'URL du webhook
	if config.outputOptions.webhook and config.webhookUrl
		try
			const url = new URL(config.webhookUrl)
			if not (url.protocol === 'http:' or url.protocol === 'https:')
				errors.push("Webhook URL must use http or https protocol")
		catch
			errors.push("Invalid webhook URL format")
	
	# Valider qu'au moins une sortie est activée
	if not config.outputOptions.localDownload and not config.outputOptions.webhook
		errors.push("At least one output method must be enabled")
	
	return {
		valid: errors.length === 0
		errors: errors
	}

# Fonction pour obtenir les paramètres utilisateur avec validation
export def getSafeUserConfig
	try
		const config = await browser.storage.sync.get([
			'filenameTemplate'
			'webhookUrl'
			'outputOptions'
		])
		
		const userConfig = {
			filenameTemplate: config.filenameTemplate || '%Y-%M-%D_%h-%m-%s_%W_%T'
			webhookUrl: config.webhookUrl || ''
			outputOptions: config.outputOptions || {
				localDownload: true
				webhook: false
			}
		}
		
		const validation = validateUserConfig(userConfig)
		
		if not validation.valid
			console.warn "User config validation errors:", validation.errors
			# Revenir aux valeurs par défaut en cas d'erreur
			return {
				filenameTemplate: '%Y-%M-%D_%h-%m-%s_%W_%T'
				webhookUrl: ''
				outputOptions: {
					localDownload: true
					webhook: false
				}
			}
		
		return userConfig
	catch error
		console.error "Error getting user config:", error
		return {
			filenameTemplate: '%Y-%M-%D_%h-%m-%s_%W_%T'
			webhookUrl: ''
			outputOptions: {
				localDownload: true
				webhook: false
			}
		}