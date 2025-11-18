import browser from 'webextension-polyfill'
import {launchScraping} from "./scraping"
import {EXTRACTION_ALLOWED_PAGES} from "./data/extractionAllowedPages.imba"

const actionAPI = browser.action || browser.browserAction; 				# Firefox compatibility
const ACTION_CONTEXT = browser.action ? "action" : "browser_action";	# Firefox compatibility

export def initBrowserInterface
	buildContextMenu!
	listenTabsToUpdateIcon!

def buildContextMenu
	browser.runtime.onInstalled.addListener(do
		browser.contextMenus.create({
			id: "openOptions",
			title: "⚙️ Export Options",
			contexts: [ACTION_CONTEXT]
		})
		browser.contextMenus.create({
			id: "tutorial",
			title: "❓ User's Guide",
			contexts: [ACTION_CONTEXT]
		})
		browser.contextMenus.create({
			id: "separator",
			type: "separator",
			contexts: [ACTION_CONTEXT]
		})
		browser.contextMenus.create({
			id: "feedback",
			title: "🤩 Share your feedback on the store",
			contexts: [ACTION_CONTEXT]
		})
		browser.contextMenus.create({
			id: "bugReport",
			title: "🚀 Report a bug or suggest a feature",
			contexts: [ACTION_CONTEXT]
		})
		browser.contextMenus.create({
			id: "donation",
			title: "❤️ Support the project",
			contexts: [ACTION_CONTEXT]
		})
		browser.contextMenus.create({
			id: "exportPage",
			title: "Export this page",
			contexts: ["page"]
		})
	)

	browser.contextMenus.onClicked.addListener do(info, tab\(browser.tabs.Tab))
		switch (info.menuItemId)
			when "openOptions"
				browser.runtime.openOptionsPage!
			when "feedback"
				await browser.tabs.create({url: "https://save.hugocollin.com/review"})
			when "donation"
				await browser.tabs.create({url: "https://save.hugocollin.com/support"})
			when "tutorial"
				await browser.windows.create({url: "https://save.hugocollin.com/tutorial", type: "popup", width: 500, height: 600})
			when "exportPage"
				await launchScraping(tab)
			when "bugReport"
				await browser.tabs.create({url: "https://save.hugocollin.com/discussion"})

def listenTabsToUpdateIcon
	# Change icon when tab is updated
	browser.tabs.onUpdated.addListener do(tabId, changeInfo, tab)
		if changeInfo.status === 'complete'
			defineIcon(tabId, tab.url)
	
	# Change icon when switching tabs
	browser.tabs.onActivated.addListener do(activeInfo)
		const tab = await browser.tabs.get(activeInfo.tabId)
		defineIcon(activeInfo.tabId, tab.url)
	
	# Change icon when switching windows
	browser.windows.onFocusChanged.addListener do(windowId)
		if windowId !== browser.windows.WINDOW_ID_NONE
			const tabs = await browser.tabs.query({active: true, windowId: windowId})
			if tabs[0]
				defineIcon(tabs[0].id, tabs[0].url)

def defineIcon(tabId, url)
	return unless url
	
	const isExportable = checkIfExportable(url)
	
	# Set icon based on page exportability
	const iconPath = getIconPath(isExportable, url)
	
	try
		await actionAPI.setIcon({
			path: {"48": iconPath}
			tabId: tabId
		})
	catch error
		console.error "Error setting icon:", error

def checkIfExportable(url)
	# Check if URL matches any allowed page
	for own key, pattern of EXTRACTION_ALLOWED_PAGES
		if url.includes(pattern)
			return true
	
	return false

# Determine icon based on URL
def getIconPath isExportable, url
	let basePath = "./assets/icons/"
	return basePath + (isExportable ? "icon_web-48.png" : "icon_disabled-48.png")