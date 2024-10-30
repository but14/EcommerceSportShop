const express = require('express')
const app = express()
app.use(express.json()); // Add this line

require('dotenv').config()

// mở kết nối tới Mongoose
const mongoose = require('mongoose');
main().then(()=>{
  console.log("Thành công kết nối Mongoose");
})
.catch(err => console.log(err));
async function main() {
  await mongoose.connect(process.env.MONGODB_URI);
}
// Mở port để angular connect được
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
  res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With,content-type');
  res.setHeader('Access-Control-Allow-Credentials', true);
  next();
});

// khai báo các Collection để tạo Collection trong mongooseDB
const users = require('./schema/usersSchema')
const products = require('./schema/productsSchema')
const categories = require('./schema/categoriesSchema')
const orders = require('./schema/ordersSchema')
// các hàm như create, update, sẽ được dùng thông qua các model không phải các Schema

// validate email
const validator = require('validator');
const nodemailer = require('nodemailer');
// Bcruypt
const bcrypt = require('bcrypt');
// JWT
var jwt = require('jsonwebtoken');
// body-parse
var bodyParser = require('body-parser')
//parse application/json
app.use(bodyParser.json())
//parse application/x-www-form-urlencoded
app.use(bodyParser.urlencoded({ extended: true }));


const port = process.env.PORT
app.listen(port, () => {
    console.log(`Example app listening on port ${port}`)
})


function response(code,data,error) {
  if(code == 200){
    return {code, data }
  }
  return {code , error }
}
function ChangeToSlug(title)
{
    var  slug;
 
    //Đổi chữ hoa thành chữ thường
    slug = title.toLowerCase();
 
    //Đổi ký tự có dấu thành không dấu
    slug = slug.replace(/á|à|ả|ạ|ã|ă|ắ|ằ|ẳ|ẵ|ặ|â|ấ|ầ|ẩ|ẫ|ậ/gi, 'a');
    slug = slug.replace(/é|è|ẻ|ẽ|ẹ|ê|ế|ề|ể|ễ|ệ/gi, 'e');
    slug = slug.replace(/i|í|ì|ỉ|ĩ|ị/gi, 'i');
    slug = slug.replace(/ó|ò|ỏ|õ|ọ|ô|ố|ồ|ổ|ỗ|ộ|ơ|ớ|ờ|ở|ỡ|ợ/gi, 'o');
    slug = slug.replace(/ú|ù|ủ|ũ|ụ|ư|ứ|ừ|ử|ữ|ự/gi, 'u');
    slug = slug.replace(/ý|ỳ|ỷ|ỹ|ỵ/gi, 'y');
    slug = slug.replace(/đ/gi, 'd');
    //Xóa các ký tự đặt biệt
    slug = slug.replace(/\`|\~|\!|\@|\#|\||\$|\%|\^|\&|\*|\(|\)|\+|\=|\,|\.|\/|\?|\>|\<|\'|\"|\:|\;|_/gi, '');
    //Đổi khoảng trắng thành ký tự gạch ngang
    slug = slug.replace(/ /gi, "-");
    //Đổi nhiều ký tự gạch ngang liên tiếp thành 1 ký tự gạch ngang
    //Phòng trường hợp người nhập vào quá nhiều ký tự trắng
    slug = slug.replace(/\-\-\-\-\-/gi, '-');
    slug = slug.replace(/\-\-\-\-/gi, '-');
    slug = slug.replace(/\-\-\-/gi, '-');
    slug = slug.replace(/\-\-/gi, '-');
    //Xóa các ký tự gạch ngang ở đầu và cuối
    slug = '@' + slug + '@';
    slug = slug.replace(/\@\-|\-\@|\@/gi, '');
    //In slug ra textbox có id “slug”
    return slug;
}

// set up cấu hình lưu trong Multer
// Multer xử lí các file khi user upload
const multer = require('multer');
const path = require('path'); 
var storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, 'public/images') // thư mục lưu tệp
  },
  filename: function (req, file, cb) {
    cb(null, file.fieldname + '-' + Date.now()+ path.extname(file.originalname)) // tên file + timestamps để có tên này là duy nhất + đường dẫn lưu đúng định dạng gốc
  }
})
var upload = multer({ storage: storage })

////////////USERS /////////////

// nhận vào data -> validate nó -> truy vấn cơ sở dữ liệu  bằng create() 
app.post('/api/user/create', upload.single('avatar') , async(req, res) => {
  try {
    let { user_email , user_name , user_password ,  user_phone, user_gender , user_birth, user_address  } = req.body 
    let avatar = req.file
    if(!avatar) return res.send(response(300,'',"Không được để trống ảnh đại diện !"));

    // regular expression  : validate data from response
    if(user_email.trim() == '' || user_name.trim() == '' || user_phone == '' || user_password.trim() == '' || user_birth.trim() == '' || user_gender.trim() == '' || user_address.trim() == ''){
      return res.send(response(300,'',"Không được để trống các Ô !"));
    }
    if (!validator.isEmail(user_email)) {
      return res.send(response(300, '', "Invalid email!"));
    }

    req.body['user_email']    = user_email
    req.body['user_name']     = user_name
    req.body['user_password'] = bcrypt.hashSync(user_password, 10)
    req.body['avatar']        = avatar.filename 
    req.body['user_phone']    = user_phone
    req.body['user_gender']   = user_phone
    req.body['user_birth']    = user_birth
    req.body['user_address']  = user_address
    
    const dataUser = await users.create(req.body)
    res.send(response(200 , dataUser))

  } catch (error) {
    if(error.errorResponse) res.send(response(error.errorResponse.code , '' , error.errorResponse.errmsg))
    else console.log(error)
  }

})

//nhận vào 2 tham số email, password -> validate -> truy vấn Db users -> dùng hàm compare() so sánh với mật khẩu và check email -> thông báo login thành công và sau đó cung cấp 1 Token cho người này -> fornt end sex lưu trữ ở trên LocalStorage
app.post('/api/user/login' , async (req,res)=>{
  try {
    var { user_email , user_password } = req.body
    if (!validator.isEmail(user_email)) {
      return res.send(response(504, '', "Invalid email!"));
    }
    if(user_email == '' || user_password == '' ){
      return res.send(response(504,'',"Không được để trống các Ô !"))
    }

    const dataUser = await users.find({user_email}).exec()
    if(dataUser.length == 0){
      return res.send(response(504, '' , 'Cannot find this email!'))
    }
    const ComparePass = bcrypt.compareSync(user_password, dataUser[0].user_password) // true or false
    if(ComparePass !== true){
      return res.send(response(504,'',"Wrong email or password!"))
    }
    dataToken = {
      _id        : dataUser[0]._id,
      user_email : dataUser[0].user_email,
      user_name  : dataUser[0].user_name,
      user_phone : dataUser[0].user_phone,
    }
    const token = jwt.sign({ data: dataToken }, process.env.SECRETKEY, { expiresIn: '10h' });
    res.send(response(200, token ))
  } catch (error) {
    if(error.errorResponse) res.send(response(error.errorResponse.code , '' , error.errorResponse.errmsg))
    else console.log(error)
  }
})

// 1 hàm checkToken return true or false
app.get('/api/checkToken', async (req, res)=>{
  var token = req.headers['authorization']
  if(!token) return res.send(response(404,'',"Fill your Token"))
  token = token.split(" ")[1]
  jwt.verify( token, process.env.SECRETKEY , function(err, decoded) {
    if (err) {
      return res.send(response(401,'',"Token is expired Error."))
    }else{
      return res.send(response(200,true))
    }
  }); 
})



app.post('/api/category/create',
 async (req,res,next)=>{
  var token = req.headers['authorization']
  if (!token) {
    return res.send(response(401,'',"Fill TOken!."))
  }
  token = token.split(' ')[1]
  jwt.verify(token, process.env.SECRETKEY, function(err, decoded) {
    if(err){
      return res.send(response(401,'',"Error TOken!."))
    }
    else{
      if(token === undefined){
      return res.send(response(401,'',"Undefined TOken!."))
      }
      else{
        next()
      }
    }
  });
 },
 async (req,res)=>{
  try {
    var token = req.headers['authorization']
    token = token.split(' ')[1]
    var decoded = jwt.verify(token, process.env.SECRETKEY);

    let { category_name , category_img , s_descrip } = req.body
    if(category_name === undefined || category_name.trim() == '' ) return res.send(response(504,'',"Nhập lại Name của Category này!."))
    if(category_img === undefined || category_img.trim() == '' )   return res.send(response(504,'',"Nhập lại Image của Category này!."))
    if(s_descrip === undefined || s_descrip.trim() == '' )         return res.send(response(504,'',"Nhập lại SHort Description của Category này!."))
    
    req.body['category_name']   = category_name
    req.body['category_slug']   = ChangeToSlug(category_name)
    req.body['category_img']    = category_img
    req.body['category_short_description']  =  s_descrip

    var dataCategory = await categories.create(req.body)
    res.send(response(200,dataCategory))
  } catch (e) {
    if(e.errorResponse){
      return res.send(response(e.errorResponse.code,'',e.errorResponse.errmsg))
    }else{
      console.log(e);
    } 
  }
 }
)

app.get('/api/category/getNameCategory_full' , async (req,res)=>{
  const dataCategory = await categories.find({}).select("category_name").exec()
  res.send(response(200 , dataCategory))
})

/*
+ Validate image jpg or png in Angular
 */
// receive data as JSON by req.body
app.post('/api/product/create' ,
 async (req,res,next)=>{
  var token = req.headers['authorization']
  if(!token) return res.send(response(401,'',"Fill your token pls !"))
  token = token.split(' ')[1]
  jwt.verify(token, process.env.SECRETKEY, function(err, decoded) {
    if(err){ return res.send(response(403,'',"Error token!.")) }
    else{
      if(token === undefined){
       return res.send(response(401,'',"Undefined TOken!."))
      }
      else{
        req.dataUser = decoded
        next()
      }
    }
  });
 },
 async (req, res)=>{
  try {
    let {
      product_name, product_imgs, product_short_description, product_description ,
      product_details, product_variants, categoriesID, product_supp_price
    } = req.body

    if( product_name.trim() == '' || product_short_description.trim() == '' || product_description.trim() == '' || product_supp_price == '' || categoriesID.trim() == ''){
      return res.send(response(504, '' , " Hãy điền vào các trường thông tin ."))
    }
    if(product_imgs.length === 0){
      return res.send(response(504, '' , " Hãy thêm ít nhất 1 hình ảnh cho sản phẩm này."))
    }
    if(product_details.length === 0){
      return res.send(response(504, '' , " Hãy thêm ít nhất 1 thuộc tính riêng cho sản phẩm này."))
    }
    // check ID    
    var ObjectId = require('mongoose').Types.ObjectId;
    var categoryCheck = ObjectId.isValid(categoriesID)
    if(categoryCheck === false){
      return res.send(response(504, '' ," KHong phải là ObjectId."))
    }

    const checkCategories = await categories.findOne({_id : new mongoose.Types.ObjectId(categoriesID)}).select("category_name").exec()
    if(checkCategories.length == 0) { return res.send(response(504,'' , " không có category này."))}

    product_variants.forEach(element => {
      element.variant_slug = ChangeToSlug(element.variant_name)
    });

    const data = {
      product_name : product_name,
      product_slug : ChangeToSlug(product_name),
      product_imgs : product_imgs,
      product_short_description : product_short_description,
      product_description       : product_description,
      product_details           : product_details,
      product_variants          : product_variants,
      sort        :  await products.countDocuments().exec() ,
      userID        :  req.dataUser.data._id , // thuộc về người sở hữu, người tạo ra sản phẩm này
      categories          : new mongoose.Types.ObjectId(checkCategories._id), 
      category_name       : checkCategories.category_name,               // khi truy vấn thì ko cần truy vấn tới Collection khác, tăng truy vấn tại đây
      product_supp_price  : product_supp_price,
    }
    const dataProduct = await products.create(data)
    res.send(response(200,dataProduct))
  } catch (e) {
    if(e.errorResponse)  return res.send(response(e.errorResponse.code,'' , e.errorResponse.errmsg))
    else console.log(e)
  }
 }

)

// xem thông tin Seller
var products_on_page = 17

app.post('/api/product/shop', async (req,res)=>{
  try {
    var { page = 1  , sortBy } = req.query // default : pop , or sale , price , time create
    // page = 1 nếu không cung cấp tham số page
    var Id_seller = req.body.Id_seller
    var sort_condition 
    var attribute

    var ObjectId = require("mongoose").Types.ObjectId
    var check = ObjectId.isValid(Id_seller)
    if(check === false){
      return res.send(response(504, '' ," KHong phải là ObjectId."))
    }
    const checkExist = await users.findOne({_id : Id_seller}).select("user_name user_avt_img user_phone user_address createdAt").exec()
    if(checkExist.length == 0){
      return res.send(response(504,"",'KHông có obiectId này!'))
    }

    if(sortBy == "time_desc"){
      sort_condition = -1 // giảm dần : -1  và tăng dần : 1
      attribute      = "createdAt"
    }else if(sortBy == "sales"){
      sort_condition = -1
      attribute      = "product_sold_quantity"
    }else if(sortBy == "price_asc"){
      sort_condition = 1
      attribute      = "product_variants[0].price"
    }else if(sortBy == "price_desc"){
      sort_condition = -1
      attribute      = "product_variants[0].price"
    }
    else{
      sort_condition = -1
      attribute      = "product_avg_rating"
    }
    
    const listProduct = await products.aggregate([
        { $match : { userID : new ObjectId(Id_seller)} }, // tại đây, phải có new ObjectId để xác định đây là Id của users mới được, còn không sẽ không ra kết quả nào.
        {
          $project : {
          _id : 1,
          product_name : 1,
          product_imgs : 1,
          product_sold_quantity : 1,
          product_avg_rating : 1, // :1 nghĩa là sẽ lấy , :0 sẽ không lấy
          categories   : 1 // ở đây nếu không lọc ra thì ở dưới _id của $group sẽ bằng null
          }
        },
        { $sort  : { [attribute]  : sort_condition }} ,
        { $skip  : parseInt((page - 1 ) * products_on_page ) },
        { $limit : products_on_page },
        { $group : {
          _id  : "$categories", // tên trường phải khớp với tên trường trong tài liệu ở đây là categories , nghĩa là phân nhóm theo _id của category, trong môgooose bắt buộc $group phải đi với _id để biểu trưng cho $froup này.
          products_array : {
            $push : {
              _id : "$_id",
              product_name          : "$product_name",
              product_imgs          : "$product_imgs",
              product_sold_quantity : "$product_sold_quantity",
              product_avg_rating    : "$product_avg_rating",
            }
          }
        }

        },
    ]).exec()

    if(listProduct.length == 0 ){
      return res.send(response(504,'',"không có sản phẩm nào thuộc người chủ cửa hàng này!"))
    }
    const data = {
      listProduct : listProduct,
      dataUser    : checkExist
    }
    res.send(response(200,data))
  } catch (e) {
    if(e.errorResponse)  return res.send(response(e.errorResponse.code,'' , e.errorResponse.errmsg))
    else console.log(e)
  }
})


app.post('/api/user/cart' ,
 async (req,res,next) => {
  var token = req.headers['authorization']
  if(!token) return res.send(response(401,'',"Fill your token pls !"))
  token = token.split(" ")[1]
  jwt.verify(token, process.env.SECRETKEY, function(err, decoded) {
    if(err){
      return res.send(response(404,'',"Error while validating your Token"))
    }
    else{
      if(decoded === undefined){
        return res.send(response(404,'',"Your Token is undefined"))
      }
      else{
        req.body["decoded"] = decoded
        next()
      }
    }
  });
 },
 async (req,res) =>{
  try {
    var userID  = req.body["decoded"].data._id 

    var ObjectId = require("mongoose").Types.ObjectId
    var check = ObjectId.isValid(userID)
    if(check == false){
      return res.send(response(504,'','Không phải là ObjectId'))
    }
    const checkExist = await users.find({_id : new mongoose.Types.ObjectId(userID)})
     .select("cart")
     .populate({
      path     : 'cart.product' ,
      select   : 'product_name product_imgs product_variants.price userID',
      populate : { path : 'userID' , select : 'user_name' , strictPopulate : false},
      strictPopulate : false })
    // path ở đây sẽ thay thế phần nào của các kết quả trả về trong select() và thay thế bằng đường dẫn và tài liệu của cái thay thế này
    // ở đây sẽ có product là _id của sản phẩm, ta populate thay thế thế bằng document tương ứng với _id sản phẩm này
     .exec()

    if(checkExist[0].cart.length == 0){
      return res.send(response(200,'Không có sản phẩm nào trong giỏ hàng hiện tại.',""))
    }
    res.send(response(200, checkExist))
  } catch (error) {
    if(error.errorResponse) return res.send(response(error.errorResponse.code,'', error.errorResponse.errmsg))
    else console.log(error);
  }
 }
)

app.post('/api/user/cart/create',
async (req,res,next) => {
  var token = req.headers['authorization']
  if(!token) return res.send(response(401,'',"Fill your token pls !"))
  token = token.split(" ")[1]
  jwt.verify(token, process.env.SECRETKEY, function(err, decoded) {
    if(err){
      return res.send(response(404,'',"Error while validating your Token"))
    }
    else{
      if(decoded === undefined){
        return res.send(response(404,'',"Your Token is undefined"))
      }
      else{
        req.body["decoded"] = decoded
        next()
      }
    }
  });
 },
 async (req,res) =>{
  try {
    var userID  = req.body["decoded"].data._id 
    var { product , variant_id } = req.body

    var ObjectId = require("mongoose").Types.ObjectId
    var check1 = ObjectId.isValid(product)
    if(check1 == false){
      return res.send(response(504,'','Không phải là ObjectId'))
    }
    var check2 = ObjectId.isValid(variant_id)
    if(check2 == false){
      return res.send(response(504,'','Không phải là ObjectId'))
    }

    const productInCart = await users.findOne(
      {
      _id: new mongoose.Types.ObjectId(userID),
      'cart.product'   : new mongoose.Types.ObjectId(product),
      'cart.variant_id': new mongoose.Types.ObjectId(variant_id)
      }).select('cart').exec();

    if(productInCart === null){
      // add to Cart
      await users.findByIdAndUpdate(
        { _id: new mongoose.Types.ObjectId(userID) },
        {
          $push : {         // $push được mongoose hỗ trợ để thao tác với mảng => nên dùng 
            cart : {
              product    : new mongoose.Types.ObjectId(product),
              variant_id : new mongoose.Types.ObjectId(variant_id),
              quantity   : 1,
            }
          }
        }
      ).exec()
      return res.send(response(200,'Thêm vào giỏ hàng thành công'))
    }else{
      // count + 1
      await users.findOneAndUpdate(
        {
          _id  : new mongoose.Types.ObjectId(userID), 
          'cart.product' : new mongoose.Types.ObjectId(product)
        },
        {
          $inc : { 'cart.$.quantity' : 1 }
          /* 
            sử dụng để tăng hoặc giảm giá trị của một trường số học
            số n : + n , tăng n giá trị
            số âm : -n , giảm n giá trị
          */
        }
      ).exec()
      return res.send(response(200,'Cộng vào giỏ hàng thành công + 1.'))
    }
  } catch (error) {
    if(error.errorResponse) return res.send(response(error.errorResponse.code,'', error.errorResponse.errmsg))
    else console.log(error);
  }
 }
)

app.post('/api/user/cart/delete',
async (req,res,next) => {
  var token = req.headers['authorization']
  if(!token) return res.send(response(401,'',"Fill your token pls !"))
  token = token.split(" ")[1]
  jwt.verify(token, process.env.SECRETKEY, function(err, decoded) {
    if(err){
      return res.send(response(404,'',"Error while validating your Token"))
    }
    else{
      if(decoded === undefined){
        return res.send(response(404,'',"Your Token is undefined"))
      }
      else{
        req.body["decoded"] = decoded
        next()
      }
    }
  });
 },
 async (req,res) =>{
  try {
    var userID  = req.body["decoded"].data._id 
    var { product , variant_id } = req.body

    var ObjectId = require("mongoose").Types.ObjectId
    var check1 = ObjectId.isValid(product)
    if(check1 == false){
      return res.send(response(504,'','Không phải là ObjectId'))
    }
    var check2 = ObjectId.isValid(variant_id)
    if(check2 == false){
      return res.send(response(504,'','Không phải là ObjectId'))
    }


    const deleteInCart = await users.findOneAndUpdate(
        { _id  : new mongoose.Types.ObjectId(userID) }, 
        { $pull  : { // $pull dùng xóa 1 phần tử khỏi 1 mảng
          cart : {
            product : new mongoose.Types.ObjectId(product),
            variant_id : new mongoose.Types.ObjectId(variant_id)    
          }
        }},
        { new: true } // Tùy chọn này trả về tài liệu sau khi cập nhật

    ).exec()

    if(deleteInCart !== null){
      return res.send(response(200,'Không có sản phẩm này trong giỏ hàng'))
    }else{
      // return res.send(response(200,'Đã xóa khỏi giỏ hàng thành công.'))
      return res.send(response(200,deleteInCart))
    }
/*
    +Nếu xóa thành công:
      Hàm sẽ trả về tài liệu người dùng trước khi phần tử trong mảng cart bị xóa.
      Nếu bạn muốn nhận tài liệu sau khi cập nhật, bạn có thể sử dụng tùy chọn { new: true }.
    +Nếu không xóa được hoặc không có phần tử để xóa:
      Hàm sẽ trả về null nếu không tìm thấy tài liệu nào khớp với điều kiện truy vấn.
*/
  } catch (error) {
    if(error.errorResponse) return res.send(response(error.errorResponse.code,'', error.errorResponse.errmsg))
    else console.log(error);
  }
 }
)

app.post('/api/product/:product_slug', async (req,res) => {
 try {
  var { productId } = req.body

  var ObjectId = require("mongoose").Types.ObjectId
  var check = ObjectId.isValid(productId)
  if(check == false){
    return res.send(response(504,'','Không phải là ObjectId'))
  }

  const productDetail = await products.findOne({_id : productId})
  .populate({
    path   : 'userID',
    select : 'user_email user_name user_phone user_address'
  }).exec()
  const populateUserId = productDetail.userID 
  res.send(response(200, productDetail))
    // res.send(response(200, populateUserId))


} catch (error) {
  if(error.errorResponse) return res.send(response(error.errorResponse.code,'', error.errorResponse.errmsg))
  else console.log(error);
}



})

//Single
app.post('/uploadfile', upload.single('image'), (req, res, next) => {
  const file = req.file
  if (!file) {
    const error = new Error('Please upload a file')
    error.httpStatusCode = 400
    return next(error)
  }
  res.send(response(200,file))
})

//Uploading multiple files
app.post('/uploadmultiple', upload.array('image', 12), (req, res, next) => {
  const files = req.files
  if (!files) {
    const error = new Error('Please choose files')
    error.httpStatusCode = 400
    return next(error)
  }
  res.send(response(200,files))

})

