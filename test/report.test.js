import test from 'node:test';
import assert from 'node:assert/strict';
import { createReport } from '../src/report.js';

test('report sorts services and preserves their versions', () => {
  const services = [
    { name: 'payments', version: '1.0.0' },
    { name: 'catalog', version: '2.0.0' }
  ];

  const report = createReport(services);

  assert.equal(report.project, 'GlobalSoft');
  assert.deepEqual(report.services, [
    { name: 'catalog', version: '2.0.0' },
    { name: 'payments', version: '1.0.0' }
  ]);
  assert.equal(services[0].name, 'payments');
});

test('report accepts an empty service list', () => {
  assert.deepEqual(createReport([]).services, []);
});
