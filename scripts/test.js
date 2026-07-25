const addon = require('./index.js');

console.log('Testing add(2, 3) =', addon.add(2, 3));
console.log('Testing concat("Hello ", "MoonBit") =', addon.concat("Hello ", "MoonBit"));

console.log('Testing Dual GC (External Object)...');
let ext = addon.create_obj("My Secret MoonBit Data");
console.log('Read obj:', addon.read_obj(ext));

console.log('Triggering GC to release the object...');
ext = null;
if (global.gc) {
  global.gc();
} else {
  console.log('Run with node --expose-gc to test finalizers fully.');
}

console.log('Testing Zero-Copy Buffer mutation...');
let buf = Buffer.from([10, 20, 30]);
console.log('Before mutate:', buf);
addon.mutate_buffer(buf);
console.log('After mutate:', buf);

console.log('All tests passed!');
