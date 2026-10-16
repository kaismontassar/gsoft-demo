import { mkdirSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export function createReport(services) {
  return {
    project: 'GlobalSoft',
    services: [...services].sort((a, b) => a.name.localeCompare(b.name))
  };
}

if (process.argv[1] &&
    import.meta.url === pathToFileURL(process.argv[1]).href) {
  const services = [
    { name: 'payments', version: '1.0.0' },
    { name: 'catalog', version: '2.0.0' }
  ];

  const output = JSON.stringify(createReport(services), null, 2) + '\n';

  if (process.argv.includes('--build')) {
    mkdirSync('dist', { recursive: true });
    writeFileSync('dist/release-report.json', output);
    console.log('Built dist/release-report.json');
  } else {
    process.stdout.write(output);
  }
}
