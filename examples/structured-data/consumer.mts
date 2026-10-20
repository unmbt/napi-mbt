import addon from './index.mjs';
const name: string = addon.profile({ name: 'Moon' }).name;
addon.event({ tag: 'Ready', args: [] });
// @ts-expect-error required name
addon.profile({ age: 2 });
