import axios from '@nextcloud/axios'
import { emit } from '@nextcloud/event-bus'
import { type IFileAction, Permission, Folder } from '@nextcloud/files'
import { generateUrl } from '@nextcloud/router'
import { translate as t } from '@nextcloud/l10n'
import FolderZipSvg from '@mdi/svg/svg/folder-zip.svg?raw'

const SUPPORTED_MIMES = [
	'application/zip',
	'application/x-tar',
	'application/gzip',
	'application/x-rar-compressed',
	'application/x-7z-compressed',
	'application/x-deb',
	'application/x-bzip2',
]

export const action: IFileAction = {
	id: 'extract',
	displayName: () => t('extract', 'Extract here'),
	iconSvgInline: () => FolderZipSvg,
	// Only works on a single archive node the user can write to.
	enabled({ nodes }) {
		if (nodes.length !== 1) {
			return false
		}

		const node = nodes[0]
		if (!SUPPORTED_MIMES.includes(node.mime)) {
			return false
		}

		return (node.permissions & Permission.UPDATE) !== 0
	},
	async exec({ nodes }) {
		const node = nodes[0]
		// The directory containing the archive, relative to the user root.
		const dir = node.dirname
		const data = {
			nameOfFile: node.basename,
			directory: dir,
			external: String(node.attributes['mount-type'] ?? '').startsWith('external') ? 1 : 0,
			mime: node.mime,
		}
		const url = generateUrl('/apps/extract/ajax/extract.php')

		try {
			const resp = await axios.post(url, data)
			const result = resp.data

			// We need the extracted folder so we can emit it in the next step,
			// just like it's done when a new folder is created.
			const time = result['extracted']['mtime'] * 1000
			const extracted = new Folder({
				id: result['extracted']['fileId'],
				source: result['extracted']['source'],
				root: result['extracted']['root'],
				owner: result['extracted']['owner'],
				permissions: result['extracted']['permissions'],
				mtime: new Date(time),
				// Include mount-type from parent folder as this is inherited
				attributes: {
					'mount-type': result['extracted']['mount-type'],
					'owner-id': result['extracted']['owner'],
					'owner-display-name': result['extracted']['owner-display-name'],
				},
			})

			emit('files:node:created', extracted)

			;(window as any).OCP.Files.Router.goToRoute(
				null, // use default route
				{ view: 'files', fileid: String(result['fileId']) },
				{ dir },
			)

			return true
		} catch (error) {
			console.error('Could not send extract request.', error)
			return false
		}
	},
	order: 25,
}
