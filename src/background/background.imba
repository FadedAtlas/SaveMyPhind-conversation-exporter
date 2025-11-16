import browser from 'webextension-polyfill'
import {
	checkWebpageExtractable
	getWebpageExtractionConfig
	getUserConfig
	extractWebpageContent
	formatContent
	generateOutput
} from "./scraping"

console.log "Background script loaded"

# Manage installation
browser.runtime.onInstalled.addListener do(details)
	try
		# Check if parameters already exist
		const currentSettings = await browser.storage.sync.get([
			'filenameTemplate'
			'webhookUrl'
			'outputOptions'
		])
		
		# Create an object with default values
		const defaultSettings = {
			filenameTemplate: currentSettings.filenameTemplate || '%Y-%M-%D_%h-%m-%s_%W_%T'
			webhookUrl: currentSettings.webhookUrl || ''
			outputOptions: currentSettings.outputOptions || {
				localDownload: true
				webhook: false
			}
		}
		
		# Save settings
		await browser.storage.sync.set(defaultSettings)
		
		console.log "Options initialized:", defaultSettings
		
		# Display a message according to the installation type
		if details.reason === 'install'
			console.log "Extension installed! Default settings applied."
		elif details.reason === 'update'
			const previousVersion = details.previousVersion
			console.log "Extension updated from version {previousVersion}"
	
	catch error
		console.error "Error setting default options:", error

# On icon click
browser.action.onClicked.addListener do(currentTabInfos)
	console.info "Icon clicked"
	
	# --- Launch scraping ---
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
	const userConfig\Object = await getUserConfig!

	# 4. Extract webpage content
	const pageContent\Array<HTMLElement> = await extractWebpageContent pageInfos, pageConfig, userConfig
	
	# 5. Format content
	const outputContent\Object<String:String> = formatContent pageInfos, pageContent, userConfig, pageConfig

	# 6. Generate output
	generateOutput pageInfos, outputContent, pageContent, userConfig, pageConfig

