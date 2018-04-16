# Cấu hình Gitlab xác thực Gmail và sử dụng Ip cho Repo
---
## Chuẩn bị
- Cài đặt Gitlab theo docs

- User kết nối tới gmail server cần bất tính năng `allow less secure apps`
 https://support.google.com/accounts/answer/6010255?hl=vi

## Cấu hình xác thực Gmail, trỏ ip thay vì domain  
> /etc/gitlab/gitlab.rb

__Truy cập thư mục cấu hình `/etc/gitlab/`__
```
cd /etc/gitlab/
```
__Tạo bản backup main config file__
```
cp /etc/gitlab/gitlab.rb /etc/gitlab/gitlab.rb.bak
```

__Kiểm tra nội dung hiện tại__
```
grep ^[^#] /etc/gitlab/gitlab.rb

external_url 'http://192.168.2.133'
```
> external_url = tham số thể hiện project là ip hoặc domain
__Chỉnh sửa cấu hình__
```
external_url 'http://ip' # '192.168.2.10'
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.gmail.com"
gitlab_rails['smtp_port'] = 587
gitlab_rails['smtp_user_name'] = "[username]@gmail.com"
gitlab_rails['smtp_password'] = "[passwd]"
gitlab_rails['smtp_domain'] = "smtp.gmail.com"
gitlab_rails['smtp_authentication'] = "login"
gitlab_rails['smtp_enable_starttls_auto'] = true
gitlab_rails['smtp_tls'] = false
gitlab_rails['smtp_openssl_verify_mode'] = 'peer'
gitlab_rails['smtp_ca_file'] = "/opt/gitlab/embedded/ssl/cert.pem"
```

__Áp dụng cấu hình mới__
```
gitlab-ctl reconfigure
```
> Nếu phát sinh lỗi trong file config sẽ báo lỗi

## Test cấu hình mới thiết lập
> Có thể phát sinh lỗi khi gửi mail xác thực tới người dùng

> Mỗi khi khởi động lại, cấu hình lại gitlab cần chạy lại trình debug để cập nhật các update mới

__khởi tạo Rails console:__
```
sudo gitlab-rails console production
```

__Kiểm tra delivery_method__
> Ta cấu hình SMTP cho gmail, tham số khi kiểm tra :smtp.

```
irb(main):001:0> ActionMailer::Base.delivery_method
=> :smtp
```

__Kiểm tra mail settings:__
```
irb(main):002:0> ActionMailer::Base.smtp_settings
=> {:authentication=>:login, :address=>"smtp.gmail.com", :port=>587, :user_name=>"[username]@gmail.com", :password=>"[passwd]", :domain=>"smtp.gmail.com", :enable_starttls_auto=>true, :tls=>false, :openssl_verify_mode=>"peer", :ca_file=>"/opt/gitlab/embedded/ssl/cert.pem"}
```

__Gửi mail test thông qua console__
```
irb(main):003:0> Notify.test_email('youremail@email.com', 'Hello World', 'This is a test message').deliver_now
```
> Nếu không nhận được mail hoặc không gửi được mail sẽ có log chi tiết, kiểm tra lại setting nếu báo lỗi


## Note
> Chú ý lỗi xác thực của Google gmail khi không enable tính năng `allow less secure apps`

> Chú ý lỗi xác thực SSL với google, nếu lỗi kiểm tra cấu hình `gitlab_rails['smtp_ca_file'] = "/opt/gitlab/embedded/ssl/cert.pem"`
