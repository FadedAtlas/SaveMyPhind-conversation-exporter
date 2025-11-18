import browser from 'webextension-polyfill'
import {launchScraping} from "./scraping"
import {initBrowserInterface} from "./initBrowserInterface"

const actionAPI = browser.action || browser.browserAction; # Firefox compatibility

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
actionAPI.onClicked.addListener do(currentTabInfos)
	console.info "Icon clicked"
	launchScraping currentTabInfos

initBrowserInterface!