import browser from 'webextension-polyfill'

tag OptionsApp
	prop filenameTemplate = ''
	prop webhookUrl = ''
	prop outputOptions = {
		localDownload: true
		webhook: false
	}
	prop showSaved = no
	prop activeSection = ''
	
	def mount
		loadSettings!
	
	def loadSettings
		try
			const result = await browser.storage.sync.get([
				'filenameTemplate'
				'webhookUrl'
				'outputOptions'
			])
			
			filenameTemplate = result..filenameTemplate || '%Y-%M-%D_%h-%m-%s_%W_%T'
			webhookUrl = result..webhookUrl || ''
			outputOptions = result.outputOptions || {
				localDownload: true
				webhook: false
			}
			
			imba.commit!
		catch error
			console.error "Error loading settings:", error
	
	def saveSettings
		try
			await browser.storage.sync.set({
				filenameTemplate: filenameTemplate
				webhookUrl: webhookUrl
				outputOptions: outputOptions
			})
			
			console.log "Settings saved successfully"
			console.log outputOptions
			
			# Notification au background script
			try
				const response = await browser.runtime.sendMessage({ 
					type: "SETTINGS_UPDATED"
					message: "Settings saved successfully"
				})
				console.log "Background response:", response
			catch error
				console.log "Background script not responding (this is OK)"
			
			showSavedMessage!
		catch error
			console.error "Error saving settings:", error
	
	def showSavedMessage
		showSaved = yes
		imba.commit!
		setTimeout(&, 3000) do
			showSaved = no
			imba.commit!
	
	def toggleSection section
		activeSection = (activeSection === section) ? '' : section
	
	css self
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif
		background: #f5f5f5
		min-height: 100vh
		padding: 20px
	
	css .container
		max-width: 800px
		margin: 0 auto
		background: white
		border-radius: 12px
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1)
		padding: 30px
	
	css .header
		display: flex
		align-items: center
		gap: 15px
		margin-bottom: 20px
		padding-bottom: 20px
		border-bottom: 2px solid #e0e0e0
	
	css .header img
		width: 48px
		height: 48px
	
	css .header h1
		font-size: 28px
		font-weight: 600
		color: #333
		margin: 0
	
	css .feedback
		background: #e3f2fd
		padding: 12px 16px
		border-radius: 8px
		margin-bottom: 25px
		color: #1976d2
		font-size: 14px
	
	css .feedback a
		color: #1565c0
		text-decoration: none
		font-weight: 500
		&:hover
			text-decoration: underline
	
	css .section
		margin-bottom: 20px
		border: 1px solid #e0e0e0
		border-radius: 8px
		overflow: hidden
	
	css .section-header
		background: #fafafa
		padding: 16px 20px
		cursor: pointer
		display: flex
		justify-content: space-between
		align-items: center
		transition: background 0.2s
		&:hover
			background: #f0f0f0
	
	css .section-header.active
		background: #e8f5e9
	
	css .section-title
		font-size: 16px
		font-weight: 600
		color: #333
	
	css .section-arrow
		font-size: 14px
		color: #666
		transition: transform 0.3s
	
	css .section-arrow.active
		transform: rotate(90deg)
	
	css .section-content
		padding: 0
		max-height: 0
		overflow: hidden
		transition: max-height 0.3s ease, padding 0.3s ease
	
	css .section-content.active
		max-height: 600px
		padding: 20px
	
	css .input-group
		margin-bottom: 20px
	
	css .input-group label
		display: block
		font-weight: 500
		margin-bottom: 8px
		color: #555
		font-size: 14px
	
	css .input-group input[type="text"]
		width: 100%
		padding: 10px 12px
		border: 1px solid #ddd
		border-radius: 6px
		font-size: 14px
		box-sizing: border-box
		transition: border-color 0.2s
		&:focus
			outline: none
			border-color: #4CAF50
	
	css .input-group input[type="text"]:disabled
		background: #f5f5f5
		color: #999
		cursor: not-allowed
	
	css .help-text
		margin: 15px 0
		padding: 12px
		background: #f9f9f9
		border-left: 3px solid #4CAF50
		border-radius: 4px
		font-size: 13px
		color: #666
		line-height: 1.6
	
	css .help-text strong
		color: #333
		display: block
		margin-top: 10px
		margin-bottom: 5px
	
	css .help-text ul
		margin: 5px 0
		padding-left: 20px
	
	css .help-text li
		margin: 3px 0
	
	css .checkbox-group
		margin-bottom: 15px
	
	css .checkbox-group label
		display: flex
		align-items: center
		cursor: pointer
		font-size: 14px
		color: #555
		padding: 10px
		border-radius: 6px
		transition: background 0.2s
		&:hover
			background: #f9f9f9
	
	css .checkbox-group input[type="checkbox"]
		margin-right: 10px
		width: 18px
		height: 18px
		cursor: pointer
	
	css .save-button
		background: #4CAF50
		color: white
		padding: 12px 30px
		border: none
		border-radius: 6px
		cursor: pointer
		font-size: 15px
		font-weight: 500
		margin-top: 20px
		transition: background 0.2s, transform 0.1s
		&:hover
			background: #45a049
		&:active
			transform: scale(0.98)
	
	css .success-message
		position: fixed
		top: 20px
		right: 20px
		background: #4CAF50
		color: white
		padding: 15px 25px
		border-radius: 8px
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15)
		font-size: 14px
		font-weight: 500
		animation: slideIn 0.3s ease
		z-index: 1000
	
	<self>
		<div.container>
			<div.header>
				<img src=(browser.runtime.getURL('./assets/icons/icon-48.png')) alt="Extension icon">
				<h1> "Export Options"
			
			<div.feedback>
				"Options page is currently in beta. "
				<a href="https://save.hugocolin.com/discussion" target="_blank"> "Share feedback and report bugs."
			
			# Filename Settings Section
			<div.section>
				<div.section-header.active=(activeSection === 'filename') @click=toggleSection('filename')>
					<span.section-title> "Filename Settings"
					<span.section-arrow.active=(activeSection === 'filename')> "▶"
				
				<div.section-content.active=(activeSection === 'filename')>
					<div.input-group>
						<label> "Filename format:"
						<input type="text" bind=filenameTemplate>
					
					<div.help-text>
						<p> "The filename format is a string containing placeholders that will be replaced by actual values when exporting a page."
						
						<strong> "Domain placeholders:"
						<ul>
							<li> 
								<code> "%W"
								" - Sub-domain name (e.g. \"Phind Search\", \"Perplexity Pages\")"
							<li>
								<code> "%H"
								" - Host name (e.g. \"www.chatgpt.com\")"
							<li> 
								<code> "%T"
								" - Title of the page (first 60 characters)"
						
						<strong> "Date placeholders:"
						<ul>
							<li> 
								<code> "%t"
								" - Timestamp (Unix time)"
							<li> 
								<code> "%Y"
								" - Year"
							<li> 
								<code> "%M"
								" - Month"
							<li> 
								<code> "%D"
								" - Day"
							<li> 
								<code> "%h"
								" - Hour"
							<li> 
								<code> "%m"
								" - Minutes"
							<li> 
								<code> "%s"
								" - Seconds"
			
			# Output Settings Section
			<div.section>
				<div.section-header.active=(activeSection === 'output') @click=toggleSection('output')>
					<span.section-title> "Output Settings"
					<span.section-arrow.active=(activeSection === 'output')> "▶"
				
				<div.section-content.active=(activeSection === 'output')>
					<div.help-text>
						<p> "Choose how your exports are saved and shared:"
					
					<div.checkbox-group>
						<label>
							<input type="checkbox" bind=outputOptions.localDownload>
							<span> "Local file download"
					
					<div.checkbox-group>
						<label>
							<input type="checkbox" bind=outputOptions.webhook>
							<span> "Webhook export"
					
					<div.input-group>
						<label> "Webhook URL:"
						<input type="text" bind=webhookUrl disabled=(!outputOptions.webhook)>
			
			<button.save-button @click=saveSettings> "Save changes"			
			if showSaved
				<div.success-message>
					"✓ Settings saved successfully!"

# Mount the app
imba.mount <OptionsApp>