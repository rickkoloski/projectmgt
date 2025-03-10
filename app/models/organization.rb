class Organization < ApplicationRecord
  include RowLevelSecurity
  
  has_many :users, dependent: :nullify
  has_many :projects, dependent: :destroy
  
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  
  before_validation :generate_slug, if: -> { slug.blank? && name.present? }
  
  private
  
  def generate_slug
    base_slug = name.parameterize
    self.slug = base_slug
    counter = 1
    
    # Ensure slug uniqueness
    while Organization.where(slug: self.slug).where.not(id: self.id).exists?
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end
end
