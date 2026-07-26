import { describe, expect, test } from 'vitest';
import { PDFDocument } from 'pdf-lib';

import { validateAnalysisMedia } from './media';

function structuralJPEG(width: number, height: number): Buffer {
	return Buffer.from([
		0xff, 0xd8,
		0xff, 0xe0, 0x00, 0x02,
		0xff, 0xc0, 0x00, 0x0b, 0x08,
		(height >> 8) & 0xff, height & 0xff,
		(width >> 8) & 0xff, width & 0xff,
		0x01, 0x01, 0x11, 0x00,
		0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3f, 0x00,
		0x00,
		0xff, 0xd9
	]);
}

describe('asset analysis media validation', () => {
	test('accepts a bounded JPEG whose signature and dimensions match the route contract', async () => {
		const bytes = structuralJPEG(2048, 1200);

		await expect(validateAnalysisMedia({
			kind: 'object-photo',
			contentType: 'image/jpeg',
			contentLength: bytes.byteLength,
			bytes
		})).resolves.toEqual({
			kind: 'object-photo',
			bytes,
			contentType: 'image/jpeg',
			width: 2048,
			height: 1200
		});
	});

	test('rejects a mismatched or oversized JPEG before it can reach OpenAI', async () => {
		await expect(validateAnalysisMedia({
			kind: 'object-photo',
			contentType: 'image/png',
			contentLength: 4,
			bytes: Buffer.from([0x89, 0x50, 0x4e, 0x47])
		})).rejects.toMatchObject({
			code: 'UNSUPPORTED_MEDIA_TYPE', status: 415
		});

		const tooWide = structuralJPEG(2049, 1200);
		await expect(validateAnalysisMedia({
			kind: 'object-photo',
			contentType: 'image/jpeg',
			contentLength: tooWide.byteLength,
			bytes: tooWide
		})).rejects.toMatchObject({
			code: 'INVALID_ANALYSIS_INPUT', status: 400
		});
	});

	test('requires a truthful Content-Length', async () => {
		const bytes = structuralJPEG(1, 1);
		await expect(validateAnalysisMedia({
			kind: 'object-photo',
			contentType: 'image/jpeg',
			contentLength: bytes.byteLength + 1,
			bytes
		})).rejects.toMatchObject({
			code: 'INVALID_ANALYSIS_INPUT', status: 400
		});
	});

	test('parses a non-encrypted PDF and rejects more than six pages', async () => {
		const acceptedDocument = await PDFDocument.create();
		acceptedDocument.addPage();
		const acceptedBytes = Buffer.from(await acceptedDocument.save());
		await expect(validateAnalysisMedia({
			kind: 'invoice',
			contentType: 'application/pdf',
			contentLength: acceptedBytes.byteLength,
			bytes: acceptedBytes
		})).resolves.toMatchObject({
			kind: 'invoice', contentType: 'application/pdf', pageCount: 1
		});

		const longDocument = await PDFDocument.create();
		for (let page = 0; page < 7; page += 1) longDocument.addPage();
		const longBytes = Buffer.from(await longDocument.save());
		await expect(validateAnalysisMedia({
			kind: 'invoice',
			contentType: 'application/pdf',
			contentLength: longBytes.byteLength,
			bytes: longBytes
		})).rejects.toMatchObject({ code: 'INVALID_ANALYSIS_INPUT', status: 400 });
	});
});
