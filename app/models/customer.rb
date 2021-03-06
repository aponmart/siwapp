class Customer < ActiveRecord::Base
  include MetaAttributes

  extend ModelCsv

  acts_as_paranoid
  has_many :invoices
  has_many :estimates
  has_many :recurring_invoices

  # Validation
  validates :name, presence: true

  # Behaviors
  acts_as_taggable

  before_destroy :check_invoices

  CSV_FIELDS = [
    "id", "name", "identification", "email", "contact_person",
    "invoicing_address", "shipping_address", "meta_attributes",
    "active"
  ]

  scope :with_terms, ->(terms) {
    return nil if terms.empty?
    where('name LIKE :terms OR email LIKE :terms OR identification LIKE :terms', terms: '%' + terms + '%')
  }

  scope :only_active, ->(boolean = true) {
    return nil unless boolean
    where(active: true)
  }

  def total
    invoices.where('draft = :draft', draft: false).sum :gross_amount || 0
  end

  def paid
    invoices.where('draft = :draft', draft: false).sum :paid_amount || 0
  end

  def due
    total - paid
  end

  def to_s
    if name?
      name
    elsif identification?
      identification
    elsif email?
      email
    else
      'Customer'
    end
  end

  def to_jbuilder
    Jbuilder.new do |json|
      json.(self, *(attribute_names - ["name_slug", "deleted_at"]))
    end
  end

  # returns a string with a csv format
  def self.csv(results)
    csv_string(results, self::CSV_FIELDS,
               results.meta_attributes_keys)
  end


private

  def check_invoices
    if self.total > self.paid
      errors[:base] << "This customer can't be deleted because it has unpaid invoices"
      return false
    end
    true
  end

  def self.ransackable_scopes(auth_object = nil)
    [:with_terms, :only_active]
  end

end
