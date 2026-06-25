#USER_DOC.mdとかに書きそうな内容

### .env_sampleを用意してあるので、そのファイルをコピーして編集してください！

#### .envのサンプルの作成
```bash
cp srcs/.env_sample srcs/.env
```



### seacret_keyの生成

#### ファイルの一括作成
```bash
touch db_password.txt db_root_password.txt wp_admin_password.txt wp_editor_password.txt
```

#### パスワードの一括入力
```bash
echo -n pw > db_password.txt
echo -n pw > db_root_password.txt
echo -n pw > wp_admin_password.txt
echo -n pw > wp_editor_password.txt
```



vm上で ip addr
192.168~を
scp -r tvaroux@192.168~:/tmp