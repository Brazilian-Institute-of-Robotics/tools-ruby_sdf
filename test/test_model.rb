require 'sdf/test'

describe SDF::Model do
    def models_dir
        File.join(File.dirname(__FILE__), 'data', 'models')
    end

    before do
        @model_path = SDF::XML.model_path
        SDF::XML.model_path = [models_dir]
    end
    after do
        SDF::XML.model_path = @model_path
        SDF::XML.clear_cache
    end

    it "can be created as-is" do
        model = SDF::Model.new
        assert model.each_link.to_a.empty?
        assert model.each_joint.to_a.empty?
        assert model.each_plugin.to_a.empty?
        refute model.static?
    end

    describe "load_from_model_name" do
        it "loads a gazebo model from name" do            
            model = SDF::Model.load_from_model_name("simple_model")
            assert_equal('simple test model', model.name)
        end
        it "returns the latest SDF version if max_version is nil" do                
            model= SDF::Model.load_from_model_name("versioned_model")
            assert_equal('versioned model 1.5', model.name)
        end
        it "returns the latest version matching max_version if provided" do
            model = SDF::Model.load_from_model_name("versioned_model",130)
            assert_equal('versioned model 1.3', model.name)
        end
        it "raises if the version constraint is not matched" do
            assert_raises(SDF::XML::UnavailableSDFVersionInModel) do
                SDF::Model.load_from_model_name("versioned_model",0)
            end                
        end
    end

    describe "#initialize" do
        it "resolves joints and links so that the declaration order does not matter" do
            model = SDF::Model.from_xml_string(<<-EOXML)
            <model name="m">
                <joint name="j">
                    <parent>parent_l</parent>
                    <child>child_l</child>
                </joint>
                <link name="parent_l" />
                <link name="child_l" />
            </model>
            EOXML
            assert_equal model.find_link_by_name('parent_l'), model.find_joint_by_name('j').parent_link
            assert_equal model.find_link_by_name('child_l'), model.find_joint_by_name('j').child_link
        end
    end

    describe "#each_model" do
        it "does not yield anything if the model has no models" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_model).to_a.empty?
        end
        it "yields the models otherwise" do
            root = SDF::Model.new(REXML::Document.new("<model><model name=\"0\" /><model name=\"1\" /></model>").root)

            models = root.each_model.to_a
            assert_equal 2, models.size
            models.each do |m|
                assert_kind_of SDF::Model, m
                assert_same root, m.parent
                assert_equal root.xml.elements.to_a("model[@name=\"#{m.name}\"]"), [m.xml]
            end
        end
    end

    describe "#each_link" do
        it "does not yield anything if the model has no link" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_link).to_a.empty?
        end
        it "yields the links otherwise" do
            root = SDF::Model.new(REXML::Document.new("<model><link name=\"0\" /><link name=\"1\" /></model>").root)

            links = root.enum_for(:each_link).to_a
            assert_equal 2, links.size
            links.each do |l|
                assert_kind_of SDF::Link, l
                assert_same root, l.parent
                assert_equal root.xml.elements.to_a("link[@name=\"#{l.name}\"]"), [l.xml]
            end
        end
    end

    describe "#each_joint" do
        it "does not yield anything if the model has no joint" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_joint).to_a.empty?
        end
        it "yields the joints otherwise" do
            root = SDF::Model.new(REXML::Document.new("<model><link name='parent' /><link name='child' /><joint name=\"0\"><parent>parent</parent><child>child</child></joint><joint name=\"1\"><parent>parent</parent><child>child</child>/></joint></model>").root)

            joints = root.enum_for(:each_joint).to_a
            assert_equal 2, joints.size
            joints.each do |l|
                assert_kind_of SDF::Joint, l
                assert_same root, l.parent
                assert_equal root.xml.elements.to_a("joint[@name=\"#{l.name}\"]"), [l.xml]
            end
        end
    end

    describe "#find_joint_by_name" do
        before do
            @root = SDF::Model.new(REXML::Document.new(<<-EOXML).root)
            <model name="root">
                <link name='parent_l' />
                <model name="child_m">
                    <link name='parent_l' />
                    <link name='child_l' />
                    <joint name="child_j">
                        <parent>parent_l</parent>
                        <child>child_l</child>
                    </joint>
                </model>
                <joint name="root_j">
                    <parent>parent_l</parent>
                    <child>child_m::child_l</child>
                </joint>
            </model>
            EOXML
        end

        it "find a joint in a toplevel model" do joint = @root.find_joint_by_name("root_j")
            assert_equal @root.find_link_by_name('parent_l'), joint.parent_link
            assert_equal @root.find_link_by_name('child_m::child_l'), joint.child_link
        end

        it "finds a joint in a child model" do
            joint = @root.find_joint_by_name("child_m::child_j")
            assert_equal @root.find_link_by_name('child_m::parent_l'), joint.parent_link
            assert_equal @root.find_link_by_name('child_m::child_l'), joint.child_link
        end
    end

    describe "#find_link_by_name" do
        before do
            @xml = REXML::Document.new(<<-EOXML).root
            <model name="root">
                <link name='parent_l' />
                <model name="child_m">
                    <link name='parent_l' />
                </model>
            </model>
            EOXML
            @root = SDF::Model.new(@xml)
        end

        it "finds a link in a toplevel model" do
            assert_equal @xml.elements['/model/link'], @root.find_link_by_name('parent_l').xml
        end

        it "find a link in a child model" do
            assert_equal @xml.elements['/model/model/link'], @root.find_link_by_name('child_m::parent_l').xml
        end
    end

    describe "#static?" do
        it "returns false unless specified otherwise" do
            xml = REXML::Document.new("<model />").root
            assert !SDF::Model.new(xml).static?
        end
        it "returns the converted value if a static tag is present" do
            xml = REXML::Document.new("<model><static>foobar</static></model>").root
            flexmock(SDF::Conversions).should_receive(:to_boolean).once.with(xml.elements['static']).and_return(v = flexmock)
            assert_equal v, SDF::Model.new(xml).static?
        end
    end

    describe "#pose" do
        it "returns the model's pose" do
            xml = REXML::Document.new("<model><pose>1 2 3 0 0 2</pose></model>").root
            model = SDF::Model.new(xml)
            p = model.pose
            assert Eigen::Vector3.new(1, 2, 3).approx?(p.translation)
            assert Eigen::Quaternion.from_angle_axis(2, Eigen::Vector3.UnitZ).approx?(p.rotation)
        end
    end

    describe "frame enumeration" do
        it "enumerates the frames" do
            xml = REXML::Document.new(<<-EOXML).root
            <model>
              <frame name="test0" />
              <frame name="test1" />
            </model>
            EOXML
            model = SDF::Model.new(xml)
            assert_equal ['test0', 'test1'], model.each_frame.map(&:name)
        end

        it "enumerates its children model's frames" do
            xml = REXML::Document.new(<<-EOXML).root
            <model>
              <model name="sub">
              <frame name="test0" />
              <frame name="test1" />
              </model>
            </model>
            EOXML
            model = SDF::Model.new(xml)
            assert_equal [['test0', 'sub::test0'], ['test1', 'sub::test1']],
                model.each_frame_with_name.map { |frame, name| [frame.name, name] }
        end
    end
end

