// Hypothesis: can Laya (local decision model) tell a wrong-layout word from a real one?
import { Laya } from "@receptron/laya";

// U.S. ↔ Russian – PC, same physical keys (from typo's fixture tables).
const US = "qwertyuiop[]asdfghjkl;'zxcvbnm,.QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>";
const RU = "йцукенгшщзхъфывапролджэячсмитьбюЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ";
const toRU = (s) => [...s].map((c) => RU[US.indexOf(c)] ?? c).join("");
const toUS = (s) => [...s].map((c) => US[RU.indexOf(c)] ?? c).join("");
const reread = (s) => (/[а-яё]/i.test(s) ? toUS(s) : toRU(s));

// [typed, should typo convert it?]
const cases = [
  // wrong layout: Russian typed on U.S.
  ["ghbdtn", true], ["rfr", true], ["ltkf", true], ["cgfcb,j", true], ["[jhjij", true], [",eltn", true],
  ["ntcn", true], ["hf,jnftn", true], ["gjxtve", true], ["ctujlyz", true], ["vjcrdf", true], ["pflfxf", true],
  ["ghbdtnn", true], ["Ghbdtn", true], ["ujcelfhcndj", true], ["ckjdj", true],
  // wrong layout: English typed on Russian – PC
  ["сщву", true], ["тпштч", true], ["руддщ", true], ["цщкдв", true], ["ершы", true], ["зкщоусе", true],
  ["ыукмук", true], ["вщслук", true], ["лгиусед", true], ["кузщышещкн", true],
  // correct as typed
  ["hello", false], ["world", false], ["project", false], ["nginx", false], ["kubectl", false], ["docker", false],
  ["README", false], ["schon", false], ["the", false], ["typo", false], ["json", false], ["xcode", false],
  ["привет", false], ["спасибо", false], ["сегодня", false], ["работает", false], ["код", false], ["будет", false],
  ["здравствуйте", false], ["москва", false], ["ёлка", false], ["щука", false],
  // nonsense both ways
  ["qzxv", false], ["ыфвыф", false],
];

const laya = await Laya.load({ cacheDir: process.env.LAYA_CACHE });

const pairQuestion = {
  intent: {
    type: "choice",
    instructions:
      "A user typed `typed` on their keyboard. `other_layout` is the same physical keys read under the other keyboard layout (Russian/English). Which text did the user mean to type?",
    criteria: {
      typed: "the typed text is a real word, name or technical term the user meant",
      other_layout: "the user forgot to switch the keyboard layout; other_layout is the real word they meant",
    },
  },
};
const wordQuestion = {
  real: { type: "noul", instructions: "Is `text` a real word, name or technical term in English or Russian, rather than keyboard gibberish?" },
};

const pct = (xs, p) => xs.slice().sort((a, b) => a - b)[Math.min(xs.length - 1, Math.floor(p * xs.length))];
await laya.systemOne({ typed: "warm", other_layout: "цфкь" }, pairQuestion); // warm-up

const timesPair = [], timesWord = [];
let okPair = 0, okWord = 0, fpPair = 0, fpWord = 0, posN = 0, negN = 0;
console.log("typed        other         | pair P(other) | P(real typed) P(real other) | expect");
for (const [typed, expect] of cases) {
  const other = reread(typed);
  let t = performance.now();
  const pair = await laya.systemOne({ typed, other_layout: other }, pairQuestion);
  timesPair.push(performance.now() - t);
  t = performance.now();
  const a = await laya.systemOne({ text: typed }, wordQuestion);
  const b = await laya.systemOne({ text: other }, wordQuestion);
  timesWord.push((performance.now() - t) / 2);

  const pOther = pair.answers.intent.probabilities.other_layout;
  const pTyped = a.answers.real.noul, pRe = b.answers.real.noul;
  const decidePair = pOther > 0.5, decideWord = pRe - pTyped > 0.3;
  if (expect) posN++; else negN++;
  if (decidePair === expect) okPair++; else if (!expect) fpPair++;
  if (decideWord === expect) okWord++; else if (!expect) fpWord++;
  const mark = (d) => (d === expect ? "✓" : "✗");
  console.log(
    `${typed.padEnd(12)} ${other.padEnd(13)} | ${pOther.toFixed(3)} ${mark(decidePair)}      | ${pTyped.toFixed(3)}       ${pRe.toFixed(3)} ${mark(decideWord)}       | ${expect ? "convert" : "keep"}`,
  );
}
const n = cases.length;
console.log(`\ncases: ${n} (${posN} wrong-layout, ${negN} correct)`);
console.log(`pair choice : accuracy ${okPair}/${n}, false corrections ${fpPair}/${negN}, latency p50 ${pct(timesPair, 0.5).toFixed(0)} ms, p95 ${pct(timesPair, 0.95).toFixed(0)} ms`);
console.log(`per-word P  : accuracy ${okWord}/${n}, false corrections ${fpWord}/${negN}, latency p50 ${pct(timesWord, 0.5).toFixed(0)} ms, p95 ${pct(timesWord, 0.95).toFixed(0)} ms per string`);
console.log(`RSS after run: ${(process.memoryUsage().rss / 1e9).toFixed(2)} GB`);
await laya.close();
