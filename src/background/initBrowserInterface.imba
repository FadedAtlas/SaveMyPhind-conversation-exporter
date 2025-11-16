import browser from 'webextension-polyfill'
import {launchScraping} from "./scraping"

export def initBrowserInterface
	buildContextMenu!
	# listenIconClick!
	# listenTabsToUpdateIcon!

def buildContextMenu
	browser.runtime.onInstalled.addListener(do
		browser.contextMenus.create({
			id: "openOptions",
			title: "⚙️ Export Options",
			contexts: ["action"]
		})
		browser.contextMenus.create({
			id: "tutorial",
			title: "❓ User's Guide",
			contexts: ["action"]
		})
		browser.contextMenus.create({
			id: "separator",
			type: "separator",
			contexts: ["action"]
		})
		browser.contextMenus.create({
			id: "feedback",
			title: "🤩 Share your feedback on the store",
			contexts: ["action"]
		})
		browser.contextMenus.create({
			id: "bugReport",
			title: "🚀 Report a bug or suggest a feature",
			contexts: ["action"]
		})
		browser.contextMenus.create({
			id: "donation",
			title: "❤️ Support the project",
			contexts: ["action"]
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
				await browser.tabs.create({url: "https://save.hugocollin.com/support"})