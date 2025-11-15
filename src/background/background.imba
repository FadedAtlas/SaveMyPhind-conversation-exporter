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
	if details.reason === 'install'
		console.log "Extension installed"
		browser.storage.sync.set {
			initialized: true
			installDate: Date.now!
		}
	elif details.reason === 'update'
		console.log "Extension updated"

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
	const userConfig\Object = getUserConfig!

	# 4. Extract webpage content
	const pageContent\Array<HTMLElement> = await extractWebpageContent pageInfos, pageConfig, userConfig
	
	# 5. Format content
	const outputContent\Object<String:String> = formatContent pageInfos, pageContent, userConfig, pageConfig

	# 6. Generate output
	generateOutput pageInfos, outputContent

