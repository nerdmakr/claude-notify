# Homebrew 배포 가이드

## 완료된 작업 ✅

1. **Code Signing** - Developer ID로 서명 완료
2. **Distribution Package** - `CNotify.zip` 생성
3. **Homebrew Cask** - `cnotify.rb` formula 작성

## 배포 단계

### 1. GitHub Repository 생성

```bash
cd /Users/tony/Documents/develop/cnotify
git init
git add .
git commit -m "Initial commit: CNotify app"
gh repo create cnotify --public --source=. --remote=origin --push
```

### 2. GitHub Release 생성

```bash
gh release create v1.0.0 \
  --title "CNotify v1.0.0" \
  --notes "First release with Soft Peach color theme" \
  CNotify.zip
```

### 3. Homebrew Cask Formula 업데이트

`cnotify.rb` 파일에서 `YOUR_USERNAME`을 실제 GitHub username으로 변경:

```ruby
url "https://github.com/YOUR_USERNAME/cnotify/releases/download/v#{version}/CNotify.zip"
homepage "https://github.com/YOUR_USERNAME/cnotify"
```

### 4. Homebrew Tap 생성 (선택사항)

개인 tap을 만들어서 배포:

```bash
# 새 repo 생성
gh repo create homebrew-tap --public

# Formula 추가
cp cnotify.rb ~/homebrew-tap/Casks/
cd ~/homebrew-tap
git add Casks/cnotify.rb
git commit -m "Add cnotify cask"
git push
```

사용자 설치:
```bash
brew tap YOUR_USERNAME/tap
brew install --cask cnotify
```

### 5. Homebrew 공식 Cask에 PR (선택사항)

```bash
# Fork homebrew-cask
gh repo fork homebrew/homebrew-cask

# Formula 추가하고 PR 생성
```

## 파일 정보

- **App Bundle**: `CNotify.app`
- **Signed & Zipped**: `CNotify.zip` (97KB)
- **SHA256**: `3bd6a954baa0958063de7f8e71c0f0a062894bfe0d1e52ce419ed055ce55a004`
- **Code Signed**: ✅ Developer ID Application: YANGWON JO
- **Runtime Hardened**: ✅

## 서명 정보 확인

```bash
codesign -dv --verbose=4 CNotify.app
spctl -a -vv CNotify.app
```

## 업데이트 방법

새 버전 릴리스 시:

1. 앱 빌드 및 서명
2. ZIP 생성 및 SHA256 계산
3. GitHub Release 생성
4. `cnotify.rb`의 `version`과 `sha256` 업데이트
