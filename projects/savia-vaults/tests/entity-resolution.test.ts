import { describe, it, expect } from 'vitest';
import { canonicalizeId, EntityResolver } from '../src/knowledge/entity-resolution.js';

describe('SE-329 canonicalizeId', () => {
  it('AC-1: normaliza acentos, case y espacios', () => {
    expect(canonicalizeId('Área De Negocio')).toBe(canonicalizeId('area-de-negocio'));
  });

  it('AC-1b: guiones y guiones bajos se tratan igual', () => {
    expect(canonicalizeId('proyecto alpha')).toBe('proyecto-alpha');
    expect(canonicalizeId('proyecto_alpha')).toBe('proyecto-alpha');
  });

  it('AC-1c: trim de espacios', () => {
    expect(canonicalizeId('  hola  ')).toBe('hola');
  });
});

describe('SE-329 EntityResolver', () => {
  const entities = [
    { id: 'area-de-negocio', alias: ['Área De Negocio', 'ADN'] },
    { id: 'cliente-acme', alias: ['Cliente ACME', 'ACME Corp'] },
    { id: 'sin-alias' },
  ];

  it('AC-2: alias resuelve al id canónico', () => {
    const resolver = new EntityResolver();
    resolver.build(entities);
    expect(resolver.resolve('Área De Negocio')).toBe('area-de-negocio');
    expect(resolver.resolve('ADN')).toBe('area-de-negocio');
    expect(resolver.resolve('Cliente ACME')).toBe('cliente-acme');
  });

  it('AC-3: input sin alias coincide → resuelve a sí mismo', () => {
    const resolver = new EntityResolver();
    resolver.build(entities);
    expect(resolver.resolve('sin-alias')).toBe('sin-alias');
    expect(resolver.resolve('SIN ALIAS')).toBe('sin-alias');
  });

  it('AC-4: input inexistente → undefined, no lanza', () => {
    const resolver = new EntityResolver();
    resolver.build(entities);
    expect(resolver.resolve('no-existe')).toBeUndefined();
  });

  it('AC-7: colisión de canonicalización se reporta', () => {
    const resolver = new EntityResolver();
    const collisions = resolver.build([
      { id: 'area-de-negocio' },
      { id: 'Área De Negocio' }, // colisiona con el anterior
    ]);
    expect(collisions.length).toBe(1);
  });

  it('AC-8: determinista — mismas entradas → mismo índice', () => {
    const r1 = new EntityResolver();
    const r2 = new EntityResolver();
    r1.build(entities);
    r2.build(entities);
    expect(r1.resolve('ADN')).toBe(r2.resolve('ADN'));
  });

  it('AC-5: build vacío → resolve undefined', () => {
    const resolver = new EntityResolver();
    resolver.build([]);
    expect(resolver.resolve('cualquier')).toBeUndefined();
  });
});
