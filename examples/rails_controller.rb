# frozen_string_literal: true

# Example Rails controller for handling toyyibPay payments
# This demonstrates how to integrate toyyibPay into a Rails application

class PaymentsController < ApplicationController
  # Skip CSRF verification for callback (toyyibPay POSTs here)
  skip_before_action :verify_authenticity_token, only: [:callback]

  # Step 1: Create a payment
  def create
    @order = Order.find(params[:order_id])

    begin
      # Create a bill in toyyibPay
      bill = ToyyibPay.bills.create(
        billName: "Order ##{@order.id}",
        billDescription: @order.description,
        billPriceSetting: "0", # Fixed price
        billPayorInfo: "1",    # Payor info optional
        billAmount: (@order.total * 100).to_i.to_s, # Convert to cents
        billReturnUrl: payment_return_url(order_id: @order.id),
        billCallbackUrl: payment_callback_url,
        billPaymentChannel: "2", # Both FPX and Credit Card
        billExternalReferenceNo: @order.reference_number,
        billTo: current_user.email,
        billPhone: current_user.phone
      )

      bill_code = bill[0]["BillCode"]

      # Save bill code to order
      @order.update!(toyyibpay_bill_code: bill_code)

      # Redirect to payment page
      redirect_to ToyyibPay.bills.payment_url(bill_code), allow_other_host: true
    rescue ToyyibPay::Error => e
      flash[:error] = "Payment initialization failed: #{e.message}"
      redirect_to order_path(@order)
    end
  end

  # Step 2: Handle return from payment page
  def return
    @order = Order.find(params[:order_id])

    # Get latest transaction status
    transactions = ToyyibPay.bills.transactions(@order.toyyibpay_bill_code)

    if transactions.any? && transactions.first["billpaymentStatus"] == "1"
      flash[:success] = "Payment successful!"
      redirect_to order_path(@order)
    else
      flash[:warning] = "Payment is being processed. You will be notified once completed."
      redirect_to order_path(@order)
    end
  rescue ToyyibPay::Error => e
    flash[:error] = "Unable to verify payment: #{e.message}"
    redirect_to order_path(@order)
  end

  # Step 3: Handle payment callback (webhook)
  def callback
    # Extract payment details from toyyibPay callback
    bill_code = params[:billcode]
    status_id = params[:status_id]
    amount = params[:amount]
    reference_no = params[:refno]
    transaction_time = params[:transaction_time]

    # Find the order
    order = Order.find_by(toyyibpay_bill_code: bill_code)

    unless order
      Rails.logger.error("ToyyibPay callback: Order not found for bill code #{bill_code}")
      head :ok
      return
    end

    # Update order based on payment status
    case status_id
    when "1"
      # Payment successful
      order.mark_as_paid!(
        amount: amount,
        reference_no: reference_no,
        paid_at: transaction_time
      )

      # Send confirmation email
      OrderMailer.payment_confirmed(order).deliver_later

      Rails.logger.info("ToyyibPay: Payment successful for order #{order.id}")
    when "2"
      # Payment pending
      order.mark_as_pending!
      Rails.logger.info("ToyyibPay: Payment pending for order #{order.id}")
    when "3"
      # Payment failed
      order.mark_as_failed!
      Rails.logger.warn("ToyyibPay: Payment failed for order #{order.id}")
    end

    # Always return 200 OK to acknowledge receipt
    head :ok
  end

  private

  def payment_return_url(order_id:)
    # Generate return URL (where customer returns after payment)
    "#{request.base_url}/payments/return?order_id=#{order_id}"
  end

  def payment_callback_url
    # Generate callback URL (where toyyibPay sends payment notifications)
    "#{request.base_url}/payments/callback"
  end
end

# Example Order model methods
class Order < ApplicationRecord
  def mark_as_paid!(amount:, reference_no:, paid_at:)
    update!(
      status: "paid",
      paid_amount: amount,
      payment_reference: reference_no,
      paid_at: paid_at
    )
  end

  def mark_as_pending!
    update!(status: "pending")
  end

  def mark_as_failed!
    update!(status: "failed")
  end
end

# Example routes (add to config/routes.rb)
# Rails.application.routes.draw do
#   resources :orders do
#     post :pay, to: 'payments#create', on: :member
#   end
#
#   get '/payments/return', to: 'payments#return', as: :payment_return
#   post '/payments/callback', to: 'payments#callback', as: :payment_callback
# end
