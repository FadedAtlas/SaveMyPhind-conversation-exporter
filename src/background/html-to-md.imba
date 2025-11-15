# Conversion HTML vers Markdown avec regex (pas de DOMParser dans background workers)
# Optimisé pour les extensions Chrome/Firefox

export def htmlToMarkdown(html)
	let markdown = html
	
	# Nettoyer les espaces avant traitement
	markdown = markdown.replace(/\r\n/g, '\n')
	markdown = markdown.replace(/\r/g, '\n')
	
	# Suppression des balises script, style, noscript (AVANT toute conversion)
	# Le flag 's' permet au '.' de matcher les retours à la ligne
	markdown = markdown.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '')
	markdown = markdown.replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, '')
	markdown = markdown.replace(/<noscript\b[^>]*>[\s\S]*?<\/noscript>/gi, '')
	
	# Suppression des commentaires HTML
	markdown = markdown.replace(/<!--[\s\S]*?-->/g, '')
	
	# Conversion des titres
	markdown = markdown.replace(/<h1[^>]*>(.*?)<\/h1>/gi, '\n\n# $1\n\n')
	markdown = markdown.replace(/<h2[^>]*>(.*?)<\/h2>/gi, '\n\n## $1\n\n')
	markdown = markdown.replace(/<h3[^>]*>(.*?)<\/h3>/gi, '\n\n### $1\n\n')
	markdown = markdown.replace(/<h4[^>]*>(.*?)<\/h4>/gi, '\n\n#### $1\n\n')
	markdown = markdown.replace(/<h5[^>]*>(.*?)<\/h5>/gi, '\n\n##### $1\n\n')
	markdown = markdown.replace(/<h6[^>]*>(.*?)<\/h6>/gi, '\n\n###### $1\n\n')
	
	# Conversion des blocs de code (avant les inline code)
	markdown = markdown.replace(/<pre[^>]*><code(?:\s+class="language-(\w+)")?[^>]*>(.*?)<\/code><\/pre>/gis, do(match, lang, code)
		const language = lang || ''
		const cleanCode = decodeHtmlEntities(code).trim()
		return "\n\n```{language}\n{cleanCode}\n```\n\n"
	)
	
	# Conversion du code inline
	markdown = markdown.replace(/<code[^>]*>(.*?)<\/code>/gi, do(match, content)
		const cleaned = content.replace(/\s+/g, ' ').trim()
		return "`{cleaned}`"
	)
	
	# Conversion des liens (avant strong/em pour gérer les liens en gras)
	markdown = markdown.replace(/<a[^>]*href=["']([^"']*)["'][^>]*title=["']([^"']*)["'][^>]*>(.*?)<\/a>/gi, '[$3]($1 "$2")')
	markdown = markdown.replace(/<a[^>]*href=["']([^"']*)["'][^>]*>(.*?)<\/a>/gi, '[$2]($1)')
	
	# Conversion des images
	markdown = markdown.replace(/<img[^>]*src=["']([^"']*)["'][^>]*alt=["']([^"']*)["'][^>]*title=["']([^"']*)["'][^>]*>/gi, '![$2]($1 "$3")')
	markdown = markdown.replace(/<img[^>]*src=["']([^"']*)["'][^>]*alt=["']([^"']*)["'][^>]*>/gi, '![$2]($1)')
	markdown = markdown.replace(/<img[^>]*src=["']([^"']*)["'][^>]*>/gi, '![]($1)')
	
	# Conversion du texte en gras
	markdown = markdown.replace(/<strong[^>]*>(.*?)<\/strong>/gi, do(match, content)
		return content.trim() ? "**{content}**" : ''
	)
	markdown = markdown.replace(/<b[^>]*>(.*?)<\/b>/gi, do(match, content)
		return content.trim() ? "**{content}**" : ''
	)
	
	# Conversion du texte en italique
	markdown = markdown.replace(/<em[^>]*>(.*?)<\/em>/gi, do(match, content)
		return content.trim() ? "*{content}*" : ''
	)
	markdown = markdown.replace(/<i[^>]*>(.*?)<\/i>/gi, do(match, content)
		return content.trim() ? "*{content}*" : ''
	)
	
	# Conversion des citations
	markdown = markdown.replace(/<blockquote[^>]*>(.*?)<\/blockquote>/gis, do(match, content)
		const cleaned = content.replace(/<[^>]+>/g, '').trim()
		const lines = cleaned.split('\n').filter(do(l) l.trim())
		return "\n\n{lines.map(do(line) "> {line.trim()}").join('\n')}\n\n"
	)
	
	# Conversion des listes ordonnées
	markdown = markdown.replace(/<ol[^>]*>(.*?)<\/ol>/gis, do(match, content)
		let counter = 0
		const items = content.replace(/<li[^>]*>(.*?)<\/li>/gi, do(m, item)
			counter++
			const cleaned = item.replace(/<[^>]+>/g, '').trim()
			return "{counter}. {cleaned}\n"
		)
		return "\n\n{items}\n"
	)
	
	# Conversion des listes non ordonnées
	markdown = markdown.replace(/<ul[^>]*>(.*?)<\/ul>/gis, do(match, content)
		const items = content.replace(/<li[^>]*>(.*?)<\/li>/gi, do(m, item)
			const cleaned = item.replace(/<[^>]+>/g, '').trim()
			return "- {cleaned}\n"
		)
		return "\n\n{items}\n"
	)
	
	# Conversion des tableaux
	markdown = markdown.replace(/<table[^>]*>(.*?)<\/table>/gis, do(match, content)
		return formatTableFromHtml(content)
	)
	
	# Conversion des paragraphes
	markdown = markdown.replace(/<p[^>]*>(.*?)<\/p>/gi, '\n\n$1\n\n')
	
	# Conversion des sauts de ligne
	markdown = markdown.replace(/<br\s*\/?>/gi, '  \n')
	markdown = markdown.replace(/<hr\s*\/?>/gi, '\n\n---\n\n')
	
	# Suppression des balises div, span, etc. (garder le contenu)
	markdown = markdown.replace(/<\/?(?:span|article|section|main|header|footer|nav|aside)[^>]*>/gi, '')
	markdown = markdown.replace(/<\/?(?:div)[^>]*>/gi, '\n')
	
	# Suppression de toutes les autres balises HTML
	markdown = markdown.replace(/<[^>]+>/g, '')
	
	# Décodage des entités HTML
	markdown = decodeHtmlEntities(markdown)
	
	# Nettoyage des espaces multiples et sauts de ligne excessifs
	markdown = markdown.replace(/\ +/g, ' ')
	markdown = markdown.replace(/\n{3,}/g, '\n\n')
	markdown = markdown.trim()
	
	return markdown

def formatTableFromHtml(tableContent)
	const rows = []
	let hasHeader = false
	
	# Extraire les lignes
	tableContent.replace(/<tr[^>]*>(.*?)<\/tr>/gis, do(match, rowContent)
		const cells = []
		const isHeader = /<th[^>]*>/i.test(rowContent)
		
		rowContent.replace(/<t[hd][^>]*>(.*?)<\/t[hd]>/gi, do(m, cell)
			const cleaned = cell.replace(/<[^>]+>/g, '').trim()
			cells.push(cleaned)
		)
		
		if cells.length > 0
			rows.push({ cells, isHeader })
			if isHeader
				hasHeader = true
	)
	
	if rows.length === 0
		return ''
	
	let markdown = '\n\n'
	
	for row, index in rows
		markdown += '| ' + row.cells.join(' | ') + ' |\n'
		
		# Ajouter le séparateur après la première ligne (header)
		if index === 0 && (hasHeader || row.isHeader)
			const separator = row.cells.map(do '---').join(' | ')
			markdown += '| ' + separator + ' |\n'
	
	markdown += '\n'
	return markdown

def decodeHtmlEntities(text)
	const entities = {
		'&nbsp;': ' '
		'&lt;': '<'
		'&gt;': '>'
		'&amp;': '&'
		'&quot;': '"'
		'&#39;': "'"
		'&#x27;': "'"
		'&apos;': "'"
		'&ldquo;': '"'
		'&rdquo;': '"'
		'&lsquo;': "'"
		'&rsquo;': "'"
		'&mdash;': '—'
		'&ndash;': '–'
		'&hellip;': '…'
	}
	
	let decoded = text
	for own entity, char of entities
		const regex = new RegExp(entity, 'g')
		decoded = decoded.replace(regex, char)
	
	# Décoder les entités numériques (&#123; ou &#xAB;)
	decoded = decoded.replace(/&#(\d+);/g, do(match, dec)
		return String.fromCharCode(parseInt(dec))
	)
	decoded = decoded.replace(/&#x([0-9a-fA-F]+);/g, do(match, hex)
		return String.fromCharCode(parseInt(hex, 16))
	)
	
	return decoded