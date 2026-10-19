import classes = require('../.napi-mbt/class-smoke/index.cjs');
import callbacks = require('../.napi-mbt/callback-smoke/index.cjs');
classes.read_counter(new classes.Counter(callbacks.invoke(x => x + 1, 1)));
callbacks.wrap(x => x).dispose();
// @ts-expect-error missing constructor argument
new classes.Counter();
// @ts-expect-error invalid callback
callbacks.invoke(null, 1);
