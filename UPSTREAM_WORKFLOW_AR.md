# إجراء مزامنة تحديثات Sozo الأصلي مع Sozo Gold

## الحالة التي تم فحصها

- مستودع Gold: `https://github.com/aimenalwaaby-prog/sozo-gold`، والفرع الجاري `gold-development`.
- المستودع الأصلي حسب `README.md` و`CONTRIBUTING.md`: `https://github.com/professorDeveloper/sozo.git`، والفرع الافتراضي `master`.
- مستودع Gold مستقل على GitHub (`isFork=false`)، لذلك لا يفترض GitHub وجود علاقة Fork أو مزامنة تلقائية.
- في نسخة العمل التي فُحصت، أُضيف remote باسم `upstream` وجُلب `upstream/master` دون دمجه أو تغيير الفرع الجاري. كانت نتيجة المقارنة وقت الفحص: Gold متقدم بـ13 التزامًا، وupstream متقدم بـ0 التزامات غير مدمجة.
- إعداد الـ remotes محلي لكل نسخة Git؛ لا ينتقل إلى نسخة جديدة بمجرد دفع commit. أعد تنفيذ خطوة إضافة `upstream` في كل نسخة عمل جديدة.

## إعداد remote والتحقق منه

```bash
git remote -v
git remote get-url upstream || git remote add upstream https://github.com/professorDeveloper/sozo.git
git fetch --no-tags upstream master
git rev-list --left-right --count gold-development...upstream/master
git log --oneline --left-right --cherry-pick gold-development...upstream/master
```

في ناتج `rev-list`، الرقم الأول هو التزامات Gold غير الموجودة في `upstream/master`، والثاني التزامات upstream غير الموجودة في Gold. لا تدمج شيئًا إذا لم تظهر تغييرات upstream جديدة.

## مزامنة آمنة عند وجود تحديثات

1. تأكد أن شجرة العمل نظيفة، ثم حدّث الفرع من مستودع Gold فقط:

   ```bash
   git status --short
   git switch gold-development
   git pull --ff-only origin gold-development
   git fetch --no-tags upstream master
   ```

2. أنشئ فرع مراجعة من `gold-development`، ولا تدمج مباشرة في `gold-development`:

   ```bash
   git switch -c sync/upstream-YYYY-MM-DD
   git merge --no-commit --no-ff upstream/master
   ```

3. راجع كل تعارض وملف متغير يدويًا. لا تستخدم `reset --hard` أو نسخًا جماعيًا لملفات upstream فوق ملفات Gold. عند تعارض غير مفهوم، ألغِ الدمج بأمان باستخدام `git merge --abort` واطلب مراجعة قبل المتابعة.

4. شغّل الاختبارات المرتبطة بالتغييرات، ثم فحوص المشروع المعتادة: `flutter analyze --no-fatal-infos`، و`dart run tool/check_translations.dart`، و`flutter test --reporter expanded`، وبناء Android وLinux. لا تخفِ الفشل ولا تغيّر توقعات الاختبارات لمجرد جعل CI أخضر.

5. بعد نجاح المراجعة والاختبارات، أنشئ commit واضحًا وادفع فرع المراجعة إلى `origin`، ثم افتح Pull Request إلى `gold-development`. لا تدفع إلى `upstream` ولا تستبدل الفرع النشط. لا يُنشأ `gold-stable` إلا بعد قرار إصدار مستقل واختبار توقيع Release الحقيقي.

## مبادئ ثابتة

- `origin` هو مستودع Gold؛ `upstream` للقراءة وجلب التغييرات من Sozo الأصلي.
- لا تُدمج تحديثات upstream آليًا أو ضمنيًا.
- لا يُعاد توجيه `origin` إلى مستودع Sozo الأصلي.
- أي تعارض يمس هوية Gold أو إعداداته أو تكاملاته الأصلية يحتاج مراجعة واعتمادًا قبل الدمج.
- حافظ على سجل الالتزامات واضحًا، ولا تدّعِ أن Gold Fork رسمي ما دام إعداد GitHub يقول `isFork=false`.
