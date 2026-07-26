import { AnalysisError } from './errors';

export const MAX_JPEG_BYTES = 4 * 1024 * 1024;
export const MAX_PDF_BYTES = 10 * 1024 * 1024;
export const MAX_IMAGE_DIMENSION = 2048;
export const MAX_PDF_PAGES = 6;

export type AnalysisKind = 'object-photo' | 'invoice';

export interface ValidatedJPEG {
	kind: 'object-photo';
	bytes: Buffer;
	contentType: 'image/jpeg';
	width: number;
	height: number;
}

export interface ValidatedPDF {
	kind: 'invoice';
	bytes: Buffer;
	contentType: 'application/pdf';
	pageCount: number;
}

export type ValidatedAnalysisMedia = ValidatedJPEG | ValidatedPDF;

interface MediaInput {
	kind: AnalysisKind;
	contentType: string | null;
	contentLength: number | null;
	bytes: Buffer;
}

export async function validateAnalysisMedia(input: MediaInput): Promise<ValidatedAnalysisMedia> {
	if (!Number.isSafeInteger(input.contentLength) || input.contentLength === null || input.contentLength <= 0) {
		throw invalidInput('Content-Length is required');
	}
	if (input.contentLength !== input.bytes.byteLength) {
		throw invalidInput('Content-Length does not match the request body');
	}

	if (input.kind === 'object-photo') {
		if (input.contentType !== 'image/jpeg') {
			throw new AnalysisError('UNSUPPORTED_MEDIA_TYPE', 415, 'Object photos must be JPEG images');
		}
		if (input.bytes.byteLength > MAX_JPEG_BYTES) {
			throw new AnalysisError('ANALYSIS_PAYLOAD_TOO_LARGE', 413, 'Object photos are limited to 4 MiB');
		}
		const { width, height } = inspectJPEG(input.bytes);
		if (width > MAX_IMAGE_DIMENSION || height > MAX_IMAGE_DIMENSION) {
			throw invalidInput('Object photos are limited to 2048 pixels per side');
		}
		return { kind: input.kind, bytes: input.bytes, contentType: input.contentType, width, height };
	}

	if (input.contentType !== 'application/pdf') {
		throw new AnalysisError('UNSUPPORTED_MEDIA_TYPE', 415, 'Invoices must be PDF documents');
	}
	if (input.bytes.byteLength > MAX_PDF_BYTES) {
		throw new AnalysisError('ANALYSIS_PAYLOAD_TOO_LARGE', 413, 'Invoices are limited to 10 MiB');
	}
	return inspectPDF(input.bytes);
}

function inspectJPEG(bytes: Buffer): { width: number; height: number } {
	if (bytes.length < 8 || bytes[0] !== 0xff || bytes[1] !== 0xd8 ||
		bytes[bytes.length - 2] !== 0xff || bytes[bytes.length - 1] !== 0xd9) {
		throw invalidInput('The JPEG structure is invalid');
	}

	let offset = 2;
	let dimensions: { width: number; height: number } | undefined;
	let sawScan = false;
	while (offset < bytes.length - 2) {
		if (bytes[offset] !== 0xff) {
			if (!sawScan) throw invalidInput('The JPEG marker stream is invalid');
			offset += 1;
			continue;
		}
		while (bytes[offset] === 0xff) offset += 1;
		const marker = bytes[offset++];
		if (marker === undefined) throw invalidInput('The JPEG marker stream is truncated');
		if (sawScan && marker === 0x00) continue;
		if (marker === 0xd9) {
			if (offset !== bytes.length) throw invalidInput('The JPEG contains trailing data');
			break;
		}
		if (marker === 0xd8 || marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
		if (offset + 2 > bytes.length) throw invalidInput('The JPEG segment is truncated');
		const length = bytes.readUInt16BE(offset);
		if (length < 2 || offset + length > bytes.length) throw invalidInput('The JPEG segment length is invalid');

		if (isStartOfFrame(marker)) {
			if (dimensions || length < 8) throw invalidInput('The JPEG frame header is invalid');
			const height = bytes.readUInt16BE(offset + 3);
			const width = bytes.readUInt16BE(offset + 5);
			if (width === 0 || height === 0) throw invalidInput('The JPEG dimensions are invalid');
			dimensions = { width, height };
		}
		if (marker === 0xda) sawScan = true;
		offset += length;
	}
	if (!dimensions || !sawScan) throw invalidInput('The JPEG is missing an image frame');
	return dimensions;
}

function isStartOfFrame(marker: number): boolean {
	return marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker);
}

async function inspectPDF(bytes: Buffer): Promise<ValidatedPDF> {
	if (bytes.length < 8 || bytes.subarray(0, 5).toString('ascii') !== '%PDF-') {
		throw invalidInput('The PDF signature is invalid');
	}
	try {
		const { PDFDocument, ParseSpeeds } = await import('pdf-lib');
		const document = await PDFDocument.load(bytes, {
			ignoreEncryption: false,
			parseSpeed: ParseSpeeds.Fastest,
			updateMetadata: false
		});
		if (document.isEncrypted) throw invalidInput('Encrypted PDFs are not supported');
		const pageCount = document.getPageCount();
		if (pageCount < 1 || pageCount > MAX_PDF_PAGES) {
			throw invalidInput(`Invoices must contain between 1 and ${MAX_PDF_PAGES} pages`);
		}
		return { kind: 'invoice', bytes, contentType: 'application/pdf', pageCount };
	} catch (error) {
		if (error instanceof AnalysisError) throw error;
		throw invalidInput('The PDF structure is invalid', error);
	}
}

function invalidInput(message: string, cause?: unknown): AnalysisError {
	return new AnalysisError('INVALID_ANALYSIS_INPUT', 400, message, undefined, { cause });
}
