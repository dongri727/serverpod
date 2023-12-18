
import { ExtensionContext } from 'vscode';
import {
	LanguageClient,
	LanguageClientOptions,
	RevealOutputChannelOn,
	ServerOptions,
	TransportKind,
} from 'vscode-languageclient/node';

let client: LanguageClient;

export function activate(context: ExtensionContext) {
	const serverOptions: ServerOptions = {
		command: 'serverpod',
		args: ['language-server'],
		options: {},
		transport: TransportKind.stdio
	};

	const clientOptions: LanguageClientOptions = {
		revealOutputChannelOn: RevealOutputChannelOn.Info,
		documentSelector: [
			{ scheme: 'file', language: 'yaml', pattern: '**/protocol/**/*.yaml' },
			{ scheme: 'file', language: 'yaml', pattern: '**/model/**/*.yaml' },
			{ scheme: 'file', pattern: '**/*.spy.yaml' },
			{ scheme: 'file', pattern: '**/*.spy.yml' },
			{ scheme: 'file', pattern: '**/*.spy' },
		],
	};

	client = new LanguageClient(
		'serverpodLanguageServer',
		'Serverpod',
		serverOptions,
		clientOptions
	);

	client.start();
}

export function deactivate(): Thenable<void> | undefined {
	if (!client) {
		return undefined;
	}
	return client.stop();
}
