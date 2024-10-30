const mongoose = require("mongoose")
const Schema = mongoose.Schema
const orderSchema = new Schema({
    customer_id      : { type : Schema.Types.ObjectId, ref: "users", require : true},
    staff_id         : { type : Schema.Types.ObjectId , ref : "users" , require : true},
    order_total_cost : { type : Number , default : 0},
    order_buyer      : { type : String , default : ''}, // tên người mua
    order_address    : [{
        district : { type : String },
        province : { type : String },
        street   : { type : String },
        ward     : { type : String }
    }],
    order_details    : [{
        _id        : { type : Schema.Types.ObjectId },
        product_id : { type : Schema.Types.ObjectId }, // lưu trữ ObjectId sản phẩm đó 
        variant_id : { type : String },
        quantity   : { type : Number , default : 0 },
        unit_price : { type : Number , default : 0 }
    }],
    order_shipping_cost : { type : Number , default : 0 },
    order_payment_cost  : { type : Number , default : 0 },
    order_status        : { type : String , default : '' },
    createdAt      : { type : Date , default : new Date()},
    updatedAt      : { type : Date }

})
module.exports = mongoose.model("orders" , orderSchema)
