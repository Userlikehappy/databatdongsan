# Bộ Dữ Liệu Bất Động Sản Việt Nam (Real Estate) 🏠📈

**Dự án xây dựng mô hình Machine Learning dự đoán giá nhà đất từ dữ liệu thực tế tại Việt Nam**


## Giới thiệu

Dự án này xây dựng một **bộ dữ liệu bất động sản toàn diện** bằng cách thu thập (crawl) dữ liệu từ trang web hàng đầu Việt Nam  [batdongsan.com.vn](https://batdongsan.com.vn).

Mục tiêu chính:
- Tạo ra bộ dữ liệu sạch, chất lượng cao để phục vụ phân tích thị trường bất động sản.
- Thực hiện **EDA chi tiết**, feature engineering và xây dựng **mô hình Machine Learning dự đoán giá nhà đất** chính xác theo khu vực, loại hình và các đặc trưng khác.
- Phát triển **dashboard trực quan** giúp người dùng dễ dàng khám phá xu hướng giá, so sánh khu vực và đưa ra quyết định mua/bán/đầu tư.
  
Dự án đặc biệt hữu ích cho:
- Người mua nhà quan tâm đến giá trị thực tế tại các khu vực đắt địa (Quận 1, Quận 3, Phú Mỹ Hưng, Vinhomes Central Park...).
- Nhà đầu tư bất động sản cần dự báo xu hướng giá.
- Các analyst và researcher nghiên cứu thị trường nhà đất Việt Nam.

Các bước cụ thể bao gồm:
- Cào dữ liệu từ website.
- Import dữ liệu vào cơ sở dữ liệu.
- Viết các module T-SQL để tiền xử lý dữ liệu.
- Thực hiện backup dữ liệu.
- Phân quyền cơ sở dữ liệu cho các nhóm người dùng khác nhau.
- Trực quan dữ liệu và xây dựng mô hình Machine Learning.

## Cấu trúc thư mục

```tree
.
├── data_crawl                  
├── data_batdongsan/
│   ├── unprocessed/          
│   └── processed/              
├── databds_clean/             
├── databds_backup/             
├── databds_notebooks/           #machineleanring
│   ├── EDA           
│   ├── Feature Creation  
│   ├── LightGBM vs XGBoost           
│   ├── Decesion Tree              
│   └── 5 Buisiness insigh            
└── databds_dashboard/
```
## Kết quả: 
- Mô hình XGBoost dự đoán được giá nhà có độ chính xác tốt nhất, dự báo được xu hướng giá cả tại các vị trí trọng điểm
```tree
 Model      R²  MAE (triệu)  MAPE (%)
0  LightGBM  0.9817    1463.4311    5.8149
1   XGBoost  0.9859    1820.1180    6.3259
```
- Khi thiết kế, chủ yếu bài viết là ở Hồ Chí Minh và Hà Nội vì số lượng khách hàng ở 2 nơi này là đông đảo nhất.
  Càng ở những vị trí đắt địa quan trọng thì giá cả nhà ở sẽ cao hơn so với mặt bằng chung khi cùng diện tích (giá/,^2), hoặc số phòng,số tầng, eg...
