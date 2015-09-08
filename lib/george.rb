#
# APPLICATION LOGIC
# ... todo: refactor and separate into different files)
#

require 'pry'
require 'json'
require 'nokogiri'
require 'csv'

module George
  TERMS_PATH = File.expand_path("../../terms", __FILE__)

  #
  # term.rb
  #

  class Term
    attr_accessor :id, :name, :start_date, :end_date, :tentative_finals_schedule_url

    def initialize(attributes)
      @id = attributes[:id]
      @name = attributes[:name]
      @start_date = attributes[:start_date]
      @end_date = attributes[:start_date]
      @tentative_finals_schedule_url = attributes[:tentative_finals_schedule_url]
    end

    def self.current
      terms_dir = Dir.new(TERMS_PATH)
      term_ids = terms_dir.entries.reject{|t| t.include?(".")} # converts [".", "..", "201502", "201503"] to ["201502", "201503"]
      term_ids = term_ids.sort #.sort_by(&:to_i) # sorts in ascending order
      term_id = term_ids.last
      term_file = File.join(TERMS_PATH, term_id, "term.json")
      term_file_contents = File.read(term_file)
      term_attributes = JSON.parse(term_file_contents, :symbolize_names => true)
      Term.new(term_attributes)
    end

    def courses_path
      File.join(TERMS_PATH, self.id, "courses")
    end

    def courses_dir
      Dir.new(self.courses_path)
    end

    def course_ids
      self.courses_dir.entries.reject{|t| t.include?(".")} # converts [".", "..", "201502", "201503"] to ["201502", "201503"]
    end

    def courses
      self.course_ids.map do |course_id|
        course_file = File.join(self.courses_path, course_id, "course.json")
        course_file_contents = File.read(course_file)
        course_attributes = JSON.parse(course_file_contents, :symbolize_names => true)
        course_attributes.merge!({:term_id => self.id})
        Course.new(course_attributes)
      end
    end
  end

  #
  # course.rb
  #

  class Course
    attr_accessor :term_id, :department_id, :id

    def initialize(attributes)
      @term_id = attributes[:term_id]
      @department_id = attributes[:department_id]
      @id = attributes[:id]
    end

    def full_id
      "#{department_id}-#{id}"
    end

    def bulletin_description_url
      "http://bulletin.gwu.edu/search/?P=#{department_id}+#{id}"
    end

    def path
      File.join(TERMS_PATH, self.term_id, "courses", self.full_id)
    end

    def sections_path
      File.join(self.path, "sections")
    end

    def sections_dir
      Dir.new(self.sections_path)
    end

    def section_ids
      self.sections_dir.entries.reject{|t| t.include?(".")} # converts [".", "..", "10", "11"] to ["10", "11"]
    end

    def sections
      self.section_ids.map do |section_id|
        section_attributes = {
          :term_id => self.term_id,
          :department_id => self.department_id,
          :course_id => self.id,
          :id => section_id
        }
        Section.new(section_attributes)
      end
    end
  end

  #
  # section.rb
  #

  class Section
    attr_accessor :id, :department_id, :course_id, :term_id

    def initialize(attributes)
      @term_id = attributes[:term_id]
      @department_id = attributes[:department_id]
      @course_id = attributes[:course_id]
      @id = attributes[:id]
    end

    def schedule_url
      "http://my.gwu.edu/mod/pws/courses.cfm?campId=1&termId=#{self.term_id}&subjId=#{self.department_id}"
    end

    def required_materials_url
      "http://www.bkstr.com/webapp/wcs/stores/servlet/booklookServlet?bookstore_id-1=122&term_id-1=#{self.term_id}&div-1=&dept-1=#{self.department_id}&course-1=#{self.course_id}&section-1=#{self.id}"
    end

    def course_full_id
      "#{self.department_id}-#{self.course_id}"
    end

    def path
      File.join(TERMS_PATH, self.term_id, "courses", self.course_full_id, "sections", self.id)
    end

    def reports_path
      File.join(path, "reports")
    end

    def summary_report_path
      File.join(reports_path, "class_summary.html")
    end

    def enrollments_report_path
      File.join(reports_path, "enrollments.csv")
    end

    def enrollments

      #
      # Get Data Table(s)
      #

      document = Nokogiri::HTML(open(summary_report_path))
      tables = document.css("table")
      data_tables = tables.select{|t| t.attributes["class"] && t.attributes["class"].value == "datadisplaytable"}
      #course_summary_table     = data_tables.find{|t| t.attributes["summary"] && t.attributes["summary"].value == "This table displays the attributes of the course." }
      #enrollment_summary_table = data_tables.find{|t| t.attributes["summary"] && t.attributes["summary"].value == "This table displays enrollment and waitlist counts." }
      enrollments_table         = data_tables.find{|t| t.attributes["summary"] && t.attributes["summary"].value == "This table displays a list of students registered for the course; summary information about each student is provided." }

      #
      # Parse Course Summary Table
      #

      # todo

      #
      # Parse Enrollment Summary Table
      #

      # todo

      #
      # Parse Enrollments Table
      #

      enrollments = []

      enrollment_rows = enrollments_table.css("tr")

      enrollment_rows.each_with_index do |enrollment, index|
        next if index == 0 # ... skip the first row (headers) where enrollment.content == "\nRecordNumber\nWaitlist Position\nStudent Name\nID\nReg Status\nLevel\nCredits\nNotification Expires\n \n"

        # Get email link

        email_link = enrollment.css("a").find{|a| a.attributes["href"].value.include?("mailto:") }

        # Parse email link

        student_email_address = email_link.attributes["href"].value.gsub("mailto:","") #net_id = email_address.gsub("@gwu.edu")
        #student_net_id = student_email_address.gsub("@gwu.edu","")
        student_full_name = email_link.attributes["target"].value

        # Get table values

        attribute_values = enrollment.children.text.strip.split("\n")

        # Parse table values

        record_number = attribute_values[0]
        waitlist_position = attribute_values[1]
        #student_name = attribute_values[2].strip
        student_gwid = attribute_values[3]
        registration_status = attribute_values[4].gsub("**","")
        level = attribute_values[5]
        credits = attribute_values[6].strip
        notification_expires = attribute_values[7].strip

        #first_name_middle_initial = student_name.split(",").last.strip
        #last_name = student_name.split(",").first.strip

        # Transform.

        enrollment_attributes = {
          :id => record_number,
          :waitlist_position => waitlist_position,
          :student_gwid => student_gwid,
          :student_email_address => student_email_address,
          :student_full_name => student_full_name,
          :registration_status => registration_status,
          :student_level => level,
          :credits => credits,
          :notification_expires => notification_expires
        }

        enrollments << enrollment_attributes
      end

      return enrollments
    end

    def generate_roster
      puts "GENERATING ROSTER FOR SECTION #{self.inspect}"

      FileUtils.rm_f(enrollments_report_path)

      @enrollments = self.enrollments

      CSV.open(enrollments_report_path, "w", :write_headers=> true, :headers => @enrollments.first.keys.map{|k| k.to_s}) do |csv|
        @enrollments.each do |enrollment_attributes|
          csv << enrollment_attributes.values
        end
      end
    end
  end
end