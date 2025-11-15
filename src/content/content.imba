import browser from 'webextension-polyfill'

console.log "Content script loaded"

# Listen for messages from background
browser.runtime.onMessage.addListener do(message, sender, sendResponse)
	console.log "Content script received message:", message
	
	if message.type === 'EXPORT_CONTENT'
		try
			const bodyHTML = document.body.innerHTML
			const response = {
				success: true
				data: {
					html: bodyHTML
					title: document.title
				}
			}
			
			# Send response back to background
			sendResponse(response)
			
		catch error
			console.error "Error extracting content:", error
			sendResponse({
				success: false
				error: error.message
			})
		
		# Return true to indicate we'll send response asynchronously
		return true