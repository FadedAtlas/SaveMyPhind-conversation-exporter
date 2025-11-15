import browser from 'webextension-polyfill'

console.log "Content script loaded"

# Listen for messages from background
browser.runtime.onMessage.addListener do(message, sender, sendResponse)
	console.log "Content script received message:", message
	
	if message.type === 'EXTRACT_CONTENT'
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
	
	if message.type === 'EXPORT_CONTENT'
		legacyDownload message..outputContent


def legacyDownload text\String, filename\String="Test"
	const blob = new Blob([text], { type: 'text/markdown' });
	const url = URL.createObjectURL(blob);
	const a = document.createElement('a');
	a.href = url;
	a.download = filename + '.md';
	document.body.appendChild(a);
	a.click();
	document.body.removeChild(a);
	URL.revokeObjectURL(url);